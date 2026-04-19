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
        for w in windows { byID[w.id] = w }

        let tracks: [AnimationTrack] = placements.compactMap { p in
            guard let w = byID[p.windowID] else { return nil }
            return AnimationTrack(windowID: p.windowID, start: w.frame, target: p.targetFrame)
        }
        guard !tracks.isEmpty else { return }

        if runner.isFinished {
            runner.start(tracks: tracks, config: config)
        } else {
            runner.interrupt(newTargets: tracks, config: config, now: clock.now())
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
        runner.tick(now: now)
        if runner.isFinished {
            stopDisplayLink()
            byID.removeAll()
        }
    }

    private func stopDisplayLink() {
        guard let link = displayLink else { return }
        CVDisplayLinkStop(link)
        displayLink = nil
    }
}
