import AppKit
import CoreGraphics
import CoreVideo
import QuartzCore
import SceneCore
import protocol SceneCore.WindowRef
import os

/// Disambiguates `WindowRef` from QuickDraw's typedef that `AppKit` transitively
/// imports — `import protocol SceneCore.WindowRef` above pulls SceneCore's
/// protocol in directly, then this typealias makes the rest of the file read
/// naturally without losing that disambiguation.
typealias SceneWindowRef = WindowRef

/// AppKit bridge for `AnimationRunner`.
///
/// Owns a `CVDisplayLink` that fires at the display's refresh rate, dispatches
/// each tick to the main thread, and forwards interpolated frames to AX writes
/// via the `WindowFrameSink` protocol. The runner itself is pure — this class
/// is the only place that touches AppKit / AX.
///
/// Thread model:
/// - `animate(...)` is called from the main thread (Coordinator).
/// - `CVDisplayLink` fires on a background CV thread; its callback re-dispatches
///   to main before calling `runner.tick(now:)`.
/// - `runner.tick` invokes `write(windowID:frame:)` synchronously, which means
///   AX writes also happen on main.
///
/// To satisfy Swift 6's strict concurrency, the class is `@MainActor` and
/// `write(windowID:frame:)` is `nonisolated` — we use `MainActor.assumeIsolated`
/// because we control all callers and they run on main.
@MainActor
final class WindowAnimator: WindowFrameSink {
    private let runner: AnimationRunner
    private let clock: Clock
    private var displayLink: CVDisplayLink?
    private var byID: [CGWindowID: any SceneWindowRef] = [:]
    /// Last frame actually written to each window. Used to suppress redundant
    /// AX writes: when the interpolator emits a frame within 0.5pt of what we
    /// last wrote, another round-trip would be indistinguishable to the target
    /// app and only costs IPC time.
    private var lastWritten: [CGWindowID: CGRect] = [:]
    /// Wall time of the most recent `tick` we actually forwarded to the runner.
    /// Used to throttle CVDisplayLink to `currentMinTickInterval` — ProMotion
    /// displays fire at 120Hz, which quadruples AX write count on Electron-family
    /// apps (Cursor, Chrome, VS Code) that respond in 30–60ms per call and
    /// bottleneck the animation to several seconds of stalled IPC.
    private var lastTickTime: Double = 0
    /// Chosen per-animation in `animate(...)`: 30Hz when any window in the set
    /// belongs to an Electron app (back-pressure protection), otherwise 60Hz for
    /// native apps whose AX responders finish in 1–3ms.
    private var currentMinTickInterval: Double = 1.0 / 30.0

    /// Bundle IDs of apps whose AX responders are known to run 10×+ slower than
    /// native. Matches at animation start; a single Electron window in the set
    /// drops the entire animation to 30Hz to avoid stalling. Extend as needed.
    private static let electronBundleIDs: Set<String> = [
        "com.microsoft.VSCode",
        "com.todesktop.230313mzl4w4u92",   // Cursor
        "com.google.Chrome",
        "com.google.Chrome.canary",
        "com.brave.Browser",
        "com.tinyspeck.slackmacgap",       // Slack
        "com.hnc.Discord",
        "com.figma.Desktop",
        "notion.id",
        "md.obsidian",
        "com.microsoft.teams2",
    ]

    private let log = Logger(subsystem: "com.scene.app", category: "animator")

    init(clock: Clock = SystemClock()) {
        self.clock = clock
        self.runner = AnimationRunner(clock: clock)
        self.runner.setSink(self)
    }

    deinit {
        if let link = displayLink {
            CVDisplayLinkStop(link)
        }
    }

    /// Start a new animation, or splice into the in-flight one without jumping.
    /// `windows` provides the live `WindowRef` instances (so we can write back to
    /// AX). `placements` maps each `windowID` to its target frame.
    func animate(windows: [any SceneWindowRef], placements: [Placement], config: AnimationConfig) {
        // Refresh the live window registry. Animations always replace the prior set.
        byID.removeAll()
        lastWritten.removeAll()
        lastTickTime = 0
        for w in windows { byID[w.id] = w }

        let tracks: [AnimationTrack] = placements.compactMap { p in
            guard let w = byID[p.windowID] else { return nil }
            return AnimationTrack(windowID: p.windowID, start: w.frame, target: p.targetFrame)
        }
        guard !tracks.isEmpty else { return }

        let hasElectron = windows.contains { w in
            guard let id = w.bundleID else { return false }
            return Self.electronBundleIDs.contains(id)
        }
        currentMinTickInterval = hasElectron ? (1.0 / 30.0) : (1.0 / 60.0)

        // User-configured durationMs is calibrated for a ~600pt diagonal move.
        // Short moves contract (snappier feel), long moves expand (less rushed),
        // clamped to ±30% of base so the user's setting still anchors the feel.
        // AnimationConfig's own [100, 500]ms clamp is the final safety net.
        let maxDistance = tracks
            .map { hypot($0.target.midX - $0.start.midX, $0.target.midY - $0.start.midY) }
            .max() ?? 600
        let baseSec = Double(config.durationMs) / 1000.0
        let scaledSec = baseSec * (maxDistance / 600.0).squareRoot()
        let clampedSec = min(max(scaledSec, baseSec * 0.7), baseSec * 1.4)
        let scaledConfig = AnimationConfig(
            enabled: config.enabled,
            durationMs: Int(clampedSec * 1000),
            easing: config.easing
        )

        if runner.isFinished {
            runner.start(tracks: tracks, config: scaledConfig)
        } else {
            runner.interrupt(newTargets: tracks, config: scaledConfig, now: clock.now())
        }
        startDisplayLinkIfNeeded()
    }

    // MARK: - WindowFrameSink

    /// Called synchronously by `runner.tick(now:)` — which we always invoke on
    /// the main thread from `tickFromDisplayLink()`. So this is safe to mark
    /// `nonisolated` and immediately re-enter the main-actor context.
    nonisolated func write(windowID: CGWindowID, frame: CGRect) {
        MainActor.assumeIsolated {
            self.writeOnMain(windowID: windowID, frame: frame)
        }
    }

    private func writeOnMain(windowID: CGWindowID, frame: CGRect) {
        guard let window = byID[windowID] else { return }
        if let prev = lastWritten[windowID], rectsApproxEqual(prev, frame, tolerance: 0.2) {
            return
        }
        lastWritten[windowID] = frame
        do { try window.setFrame(frame) }
        catch {
            log.error("AX setFrame failed for \(windowID, privacy: .public): \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: - Display link

    private func startDisplayLinkIfNeeded() {
        if displayLink != nil { return }
        var link: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&link)
        guard let link else {
            log.error("CVDisplayLinkCreateWithActiveCGDisplays failed")
            return
        }
        displayLink = link

        let context = Unmanaged.passUnretained(self).toOpaque()
        CVDisplayLinkSetOutputCallback(link, { (_, _, _, _, _, ctx) -> CVReturn in
            guard let ctx else { return kCVReturnSuccess }
            let animator = Unmanaged<WindowAnimator>.fromOpaque(ctx).takeUnretainedValue()
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    animator.tickFromDisplayLink()
                }
            }
            return kCVReturnSuccess
        }, context)
        CVDisplayLinkStart(link)
    }

    private func tickFromDisplayLink() {
        let now = clock.now()
        if lastTickTime > 0, now - lastTickTime < currentMinTickInterval { return }
        lastTickTime = now
        runner.tick(now: now)
        if runner.isFinished {
            stopDisplayLink()
            byID.removeAll()
            lastWritten.removeAll()
        }
    }

    private func stopDisplayLink() {
        guard let link = displayLink else { return }
        CVDisplayLinkStop(link)
        displayLink = nil
    }
}
