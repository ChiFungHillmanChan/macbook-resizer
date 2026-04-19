import CoreGraphics
import Foundation

/// Receives interpolated frames from `AnimationRunner`. The runner calls `write`
/// synchronously on each `tick(now:)`. SceneCore-side this is just a protocol;
/// the SceneApp `WindowAnimator` adopts it and bridges to AX.
public protocol WindowFrameSink: AnyObject {
    func write(windowID: CGWindowID, frame: CGRect)
}

/// One window's animation segment: the start frame at `t=0` and the desired
/// target frame at `t=1`.
public struct AnimationTrack: Equatable, Sendable {
    public let windowID: CGWindowID
    public let start: CGRect
    public let target: CGRect

    public init(windowID: CGWindowID, start: CGRect, target: CGRect) {
        self.windowID = windowID
        self.start = start
        self.target = target
    }
}

/// Pure animation state machine. Doesn't touch AppKit / AX; the caller drives
/// it by calling `tick(now:)` (typically from a `CVDisplayLink`) and the runner
/// invokes the injected `WindowFrameSink` with interpolated frames.
///
/// Lifecycle:
/// - `start(tracks:config:)` — begin a new animation, recording `clock.now()`
///   as the start time.
/// - `tick(now:)` — compute progress and emit one frame per active track. When
///   `t >= 1`, snap to the exact targets, mark `isFinished`, and clear state.
/// - `interrupt(newTargets:config:now:)` — replace the targets without a jump:
///   for any window currently animating, the latest emitted frame becomes the
///   new start, so motion continues from where the user actually sees it.
/// - `cancel()` — abandon any in-flight animation and clear all state.
public final class AnimationRunner {
    private let clock: Clock
    private weak var sink: WindowFrameSink?

    private var tracks: [AnimationTrack] = []
    private var config: AnimationConfig = .default
    private var startTime: Double = 0

    /// Most-recently-emitted frame per window. Used by `interrupt` to splice
    /// new targets onto the visible position without snapping.
    private var lastEmitted: [CGWindowID: CGRect] = [:]

    public init(clock: Clock) {
        self.clock = clock
    }

    public func setSink(_ sink: WindowFrameSink) {
        self.sink = sink
    }

    /// True when no animation is in progress. Initially true.
    public private(set) var isFinished: Bool = true

    /// Begin a fresh animation. Records `clock.now()` as t=0.
    public func start(tracks: [AnimationTrack], config: AnimationConfig) {
        self.tracks = tracks
        self.config = config
        self.startTime = clock.now()
        self.lastEmitted.removeAll()
        self.isFinished = tracks.isEmpty
    }

    /// Advance the animation to `now`. For each active track, compute
    /// `t = (now - startTime) / durationSec`, clamp to `[0, 1]`, interpolate
    /// via `FrameInterpolator`, and write to the sink. When `t >= 1`, snap
    /// each track to its exact target frame, mark finished, and drop tracks.
    public func tick(now: Double) {
        guard !isFinished, !tracks.isEmpty else { return }

        let durationSec = max(Double(config.durationMs) / 1000.0, 0.0001)
        let rawT = (now - startTime) / durationSec
        let done = rawT >= 1.0
        let t = min(max(rawT, 0), 1)

        for track in tracks {
            let frame: CGRect
            if done {
                frame = track.target
            } else {
                frame = FrameInterpolator.frame(
                    start: track.start,
                    target: track.target,
                    easing: config.easing,
                    t: t
                )
            }
            lastEmitted[track.windowID] = frame
            sink?.write(windowID: track.windowID, frame: frame)
        }

        if done {
            isFinished = true
            tracks.removeAll()
        }
    }

    /// Replace the in-flight animation with new targets. For each new track,
    /// if a frame was already emitted for that window, that frame becomes the
    /// new `start` (so the window doesn't jump). Otherwise the caller-supplied
    /// `start` is used. `lastEmitted` entries for windows no longer in the new
    /// track set are dropped.
    public func interrupt(newTargets: [AnimationTrack], config: AnimationConfig, now: Double) {
        // Splice each new track's start onto the latest visible frame, if any.
        let spliced: [AnimationTrack] = newTargets.map { track in
            if let lastFrame = lastEmitted[track.windowID] {
                return AnimationTrack(windowID: track.windowID, start: lastFrame, target: track.target)
            }
            return track
        }

        // Drop lastEmitted entries that no longer correspond to active windows.
        let activeIDs = Set(spliced.map(\.windowID))
        lastEmitted = lastEmitted.filter { activeIDs.contains($0.key) }

        self.tracks = spliced
        self.config = config
        self.startTime = now
        self.isFinished = spliced.isEmpty
    }

    /// Abandon the in-flight animation. Subsequent `tick(now:)` calls do nothing.
    public func cancel() {
        tracks.removeAll()
        lastEmitted.removeAll()
        isFinished = true
    }
}
