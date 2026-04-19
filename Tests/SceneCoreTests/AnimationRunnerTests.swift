import XCTest
import CoreGraphics
@testable import SceneCore

// MARK: - Test doubles

final class MockClock: Clock {
    var current: Double = 0
    func now() -> Double { current }
    func advance(by seconds: Double) { current += seconds }
}

final class RecordingSink: WindowFrameSink {
    private(set) var writes: [(id: CGWindowID, frame: CGRect)] = []
    func write(windowID: CGWindowID, frame: CGRect) {
        writes.append((windowID, frame))
    }
    func reset() { writes.removeAll() }
    var lastFrame: CGRect? { writes.last?.frame }
}

// MARK: - Tests

final class AnimationRunnerTests: XCTestCase {
    let clock = MockClock()
    let sink = RecordingSink()
    var runner: AnimationRunner!

    private let linear200ms = AnimationConfig(enabled: true, durationMs: 200, easing: .linear)
    private let linear500ms = AnimationConfig(enabled: true, durationMs: 500, easing: .linear)

    override func setUp() {
        super.setUp()
        clock.current = 0
        sink.reset()
        runner = AnimationRunner(clock: clock)
        runner.setSink(sink)
    }

    // MARK: Basic lifecycle

    func testStartEmitsStartFrameAtTZero() {
        let start = CGRect(x: 0, y: 0, width: 100, height: 100)
        let target = CGRect(x: 200, y: 0, width: 100, height: 100)
        let track = AnimationTrack(windowID: 1, start: start, target: target)

        runner.start(tracks: [track], config: linear200ms)
        runner.tick(now: clock.now())

        XCTAssertEqual(sink.writes.count, 1)
        XCTAssertEqual(sink.writes[0].id, 1)
        XCTAssertEqual(sink.writes[0].frame.minX, 0, accuracy: 1e-9)
    }

    func testHalfwayLinearIsHalfway() {
        let start = CGRect(x: 0, y: 0, width: 100, height: 100)
        let target = CGRect(x: 200, y: 0, width: 100, height: 100)
        let track = AnimationTrack(windowID: 1, start: start, target: target)

        runner.start(tracks: [track], config: linear200ms)
        clock.advance(by: 0.1)
        runner.tick(now: clock.now())

        XCTAssertEqual(sink.lastFrame?.minX ?? .nan, 100, accuracy: 1e-6)
    }

    func testReachesTargetExactlyAtEnd() {
        let start = CGRect(x: 0, y: 0, width: 100, height: 100)
        let target = CGRect(x: 200, y: 0, width: 100, height: 100)
        let track = AnimationTrack(windowID: 1, start: start, target: target)

        runner.start(tracks: [track], config: linear200ms)
        clock.advance(by: 0.2)
        runner.tick(now: clock.now())

        XCTAssertTrue(runner.isFinished)
        XCTAssertEqual(sink.lastFrame, target)
    }

    func testIsFinishedFalseMidAnimation() {
        let start = CGRect(x: 0, y: 0, width: 100, height: 100)
        let target = CGRect(x: 200, y: 0, width: 100, height: 100)
        let track = AnimationTrack(windowID: 1, start: start, target: target)

        runner.start(tracks: [track], config: linear500ms)
        clock.advance(by: 0.1)
        runner.tick(now: clock.now())

        XCTAssertFalse(runner.isFinished)
    }

    // MARK: Interruption / cancellation

    /// Interrupting halfway through an animation must not jump the window:
    /// the new track's `start` is replaced by the most-recently-emitted frame,
    /// so motion continues smoothly from the visible position.
    func testInterruptResetsStartFromCurrentInterpolatedFrame() {
        let original = AnimationTrack(
            windowID: 1,
            start: CGRect(x: 0, y: 0, width: 100, height: 100),
            target: CGRect(x: 200, y: 0, width: 100, height: 100)
        )
        runner.start(tracks: [original], config: linear200ms)

        // Advance halfway and capture frame.
        clock.advance(by: 0.1)
        runner.tick(now: clock.now())
        let halfway = sink.lastFrame!
        XCTAssertEqual(halfway.minX, 100, accuracy: 1e-6)

        // Interrupt: new target at x=400. Provide a *bogus* start that should be
        // overridden because the runner already has a lastEmitted frame for ID 1.
        let newTrack = AnimationTrack(
            windowID: 1,
            start: CGRect(x: 9999, y: 0, width: 100, height: 100), // should be discarded
            target: CGRect(x: 400, y: 0, width: 100, height: 100)
        )
        sink.reset()
        runner.interrupt(newTargets: [newTrack], config: linear200ms, now: clock.now())

        // Tick immediately at t=0 — frame should equal the spliced start (~100), not 9999.
        runner.tick(now: clock.now())
        XCTAssertEqual(sink.lastFrame?.minX ?? .nan, 100, accuracy: 1e-6)

        // Halfway through the new animation: midpoint between 100 and 400 = 250.
        clock.advance(by: 0.1)
        runner.tick(now: clock.now())
        XCTAssertEqual(sink.lastFrame?.minX ?? .nan, 250, accuracy: 1e-6)

        // Fully complete: exactly the new target.
        clock.advance(by: 0.1)
        runner.tick(now: clock.now())
        XCTAssertTrue(runner.isFinished)
        XCTAssertEqual(sink.lastFrame?.minX ?? .nan, 400, accuracy: 1e-9)
    }

    /// Interrupting with a window the runner hasn't seen before must use the
    /// caller-supplied `start` (no splicing).
    func testInterruptIgnoresUnknownWindowIDs() {
        let original = AnimationTrack(
            windowID: 1,
            start: CGRect(x: 0, y: 0, width: 100, height: 100),
            target: CGRect(x: 200, y: 0, width: 100, height: 100)
        )
        runner.start(tracks: [original], config: linear200ms)
        clock.advance(by: 0.1)
        runner.tick(now: clock.now())

        let newTrack = AnimationTrack(
            windowID: 99, // unknown to the runner
            start: CGRect(x: 500, y: 0, width: 100, height: 100),
            target: CGRect(x: 700, y: 0, width: 100, height: 100)
        )
        sink.reset()
        runner.interrupt(newTargets: [newTrack], config: linear200ms, now: clock.now())
        runner.tick(now: clock.now())

        XCTAssertEqual(sink.writes.count, 1)
        XCTAssertEqual(sink.writes[0].id, 99)
        XCTAssertEqual(sink.writes[0].frame.minX, 500, accuracy: 1e-9)
    }

    func testCancelStopsEmittingFrames() {
        let track = AnimationTrack(
            windowID: 1,
            start: CGRect(x: 0, y: 0, width: 100, height: 100),
            target: CGRect(x: 200, y: 0, width: 100, height: 100)
        )
        runner.start(tracks: [track], config: linear200ms)
        runner.tick(now: clock.now())
        XCTAssertEqual(sink.writes.count, 1)

        runner.cancel()
        XCTAssertTrue(runner.isFinished)

        sink.reset()
        clock.advance(by: 0.1)
        runner.tick(now: clock.now())
        XCTAssertEqual(sink.writes.count, 0)
    }

    /// Multiple back-to-back interrupts: only the most recently supplied target
    /// should win. The window should land exactly on target C.
    func testRapidReTriggerKeepsLatestTargetOnly() {
        let trackA = AnimationTrack(
            windowID: 1,
            start: CGRect(x: 0, y: 0, width: 100, height: 100),
            target: CGRect(x: 100, y: 0, width: 100, height: 100)
        )
        runner.start(tracks: [trackA], config: linear200ms)
        runner.tick(now: clock.now()) // emit at t=0 so lastEmitted is populated

        let trackB = AnimationTrack(
            windowID: 1,
            start: CGRect(x: 0, y: 0, width: 100, height: 100), // ignored — spliced
            target: CGRect(x: 200, y: 0, width: 100, height: 100)
        )
        runner.interrupt(newTargets: [trackB], config: linear200ms, now: clock.now())

        let trackC = AnimationTrack(
            windowID: 1,
            start: CGRect(x: 0, y: 0, width: 100, height: 100), // ignored — spliced
            target: CGRect(x: 300, y: 0, width: 100, height: 100)
        )
        runner.interrupt(newTargets: [trackC], config: linear200ms, now: clock.now())

        // Run to completion — frame must equal trackC.target exactly.
        clock.advance(by: 0.2)
        runner.tick(now: clock.now())
        XCTAssertTrue(runner.isFinished)
        XCTAssertEqual(sink.lastFrame, trackC.target)
    }
}
