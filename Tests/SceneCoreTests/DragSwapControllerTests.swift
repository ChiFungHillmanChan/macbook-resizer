import XCTest
import AppKit
import CoreGraphics
@testable import SceneCore
import protocol SceneCore.WindowRef

typealias SceneWindowRef = WindowRef

/// Boxes a mutable Int so a closure can flip it mid-test (e.g., simulate the user
/// releasing the mouse button between drag arming and animator-driven re-entry).
final class MutableButtonsBox {
    var value: Int
    init(value: Int) { self.value = value }
}

@MainActor
final class DragSwapControllerTests: XCTestCase {
    let vf = CGRect(x: 0, y: 0, width: 1000, height: 800)
    let slot0Rect = CGRect(x: 0, y: 0, width: 500, height: 800)
    let slot1Rect = CGRect(x: 500, y: 0, width: 500, height: 800)

    func makeLayout() -> Layout {
        Layout.halves
    }

    func makeScreen() -> NSScreen { NSScreen.screens[0] }

    final class RecordingSink: WindowAnimationSink {
        struct Call { let windowID: CGWindowID; let target: CGRect }
        var calls: [Call] = []
        func animate(window: any SceneWindowRef, to target: CGRect) {
            calls.append(Call(windowID: window.id, target: target))
        }
    }

    func makeController(
        layout: Layout,
        windows: [any SceneWindowRef],
        screen: NSScreen,
        config: DragSwapConfig = .default,
        modifierFlags: NSEvent.ModifierFlags = [],
        pressedButtons: Int = 0b1
    ) -> (DragSwapController, RecordingSink) {
        let sink = RecordingSink()
        // Test convention: windows[i] occupies slot i. Mirrors what the production
        // Coordinator builds from `Plan.placements` after `applyLayout`.
        let map = Dictionary(uniqueKeysWithValues: windows.enumerated().map { ($1.id, $0) })
        let ctx = DragSwapController.Context(
            layout: layout,
            screen: screen,
            windows: windows,
            windowToSlotIdx: map
        )
        let controller = DragSwapController(
            contextProvider: { ctx },
            config: { config },
            animationSink: sink,
            modifierFlagsProbe: { modifierFlags },
            mouseButtonsProbe: { pressedButtons },
            visibleFrameOverride: { _ in self.vf }
        )
        return (controller, sink)
    }

    func testDisabledConfigNoOps() {
        let wA = MockWindow(id: 1, frame: slot0Rect)
        let wB = MockWindow(id: 2, frame: slot1Rect)
        let (controller, sink) = makeController(
            layout: makeLayout(),
            windows: [wA, wB],
            screen: makeScreen(),
            config: DragSwapConfig(enabled: false, distanceThresholdPt: 30)
        )
        controller.handleWindowMoved(windowID: 1, currentFrame: slot1Rect)
        controller.simulateMouseUp()
        XCTAssertEqual(sink.calls.count, 0, "disabled controller should not animate anything")
    }

    // MARK: - Task 5: threshold / resize / modifier / self-fire gates

    func testSubThresholdDragShowsNoPreview() {
        let wA = MockWindow(id: 1, frame: slot0Rect)
        let wB = MockWindow(id: 2, frame: slot1Rect)
        let (controller, _) = makeController(
            layout: makeLayout(),
            windows: [wA, wB],
            screen: makeScreen(),
            config: DragSwapConfig(enabled: true, distanceThresholdPt: 30)
        )
        controller.handleWindowMoved(windowID: 1, currentFrame: slot0Rect)
        let nudge = slot0Rect.offsetBy(dx: 20, dy: 0)
        controller.handleWindowMoved(windowID: 1, currentFrame: nudge)

        XCTAssertNil(controller._testActiveDrag, "sub-threshold drag must not arm a swap")
    }

    func testCrossingThresholdArmsSwap() {
        let wA = MockWindow(id: 1, frame: slot0Rect)
        let wB = MockWindow(id: 2, frame: slot1Rect)
        let (controller, _) = makeController(
            layout: makeLayout(),
            windows: [wA, wB],
            screen: makeScreen()
        )
        controller.handleWindowMoved(windowID: 1, currentFrame: slot0Rect)
        controller.handleWindowMoved(windowID: 1, currentFrame: slot0Rect.offsetBy(dx: 400, dy: 0))

        XCTAssertNotNil(controller._testActiveDrag)
        XCTAssertEqual(controller._testActiveDrag?.windowID, 1)
        XCTAssertEqual(controller._testActiveDrag?.targetSlotIdx, 1)
    }

    func testResizeBailOutIgnoresSignal() {
        let wA = MockWindow(id: 1, frame: slot0Rect)
        let wB = MockWindow(id: 2, frame: slot1Rect)
        let (controller, _) = makeController(
            layout: makeLayout(),
            windows: [wA, wB],
            screen: makeScreen()
        )
        controller.handleWindowMoved(windowID: 1, currentFrame: slot0Rect)
        let resized = CGRect(x: slot0Rect.minX, y: slot0Rect.minY, width: slot0Rect.width - 50, height: slot0Rect.height)
        controller.handleWindowMoved(windowID: 1, currentFrame: resized)

        XCTAssertNil(controller._testActiveDrag)
    }

    func testOptionHeldSkipsSwap() {
        let wA = MockWindow(id: 1, frame: slot0Rect)
        let wB = MockWindow(id: 2, frame: slot1Rect)
        let (controller, _) = makeController(
            layout: makeLayout(),
            windows: [wA, wB],
            screen: makeScreen(),
            modifierFlags: [.option]
        )
        controller.handleWindowMoved(windowID: 1, currentFrame: slot0Rect)
        controller.handleWindowMoved(windowID: 1, currentFrame: slot0Rect.offsetBy(dx: 400, dy: 0))

        XCTAssertNil(controller._testActiveDrag, "⌥-held drag must opt-out of swap")
    }

    func testNoMouseButtonSkipsSwap() {
        let wA = MockWindow(id: 1, frame: slot0Rect)
        let wB = MockWindow(id: 2, frame: slot1Rect)
        let (controller, _) = makeController(
            layout: makeLayout(),
            windows: [wA, wB],
            screen: makeScreen(),
            pressedButtons: 0
        )
        controller.handleWindowMoved(windowID: 1, currentFrame: slot0Rect.offsetBy(dx: 400, dy: 0))

        XCTAssertNil(controller._testActiveDrag)
    }

    // MARK: - Task 6: placed-set filter

    func testDragOfNonPlacedWindowIsIgnored() {
        let wA = MockWindow(id: 1, frame: slot0Rect)
        let wB = MockWindow(id: 2, frame: slot1Rect)
        let (controller, _) = makeController(
            layout: makeLayout(),
            windows: [wA, wB],
            screen: makeScreen()
        )
        controller.handleWindowMoved(windowID: 99, currentFrame: slot0Rect)
        controller.handleWindowMoved(windowID: 99, currentFrame: slot0Rect.offsetBy(dx: 400, dy: 0))

        XCTAssertNil(controller._testActiveDrag)
    }

    func testDragLandingOutsideAnySlotIsIgnored() {
        let wA = MockWindow(id: 1, frame: slot0Rect)
        let wB = MockWindow(id: 2, frame: slot1Rect)
        let (controller, _) = makeController(
            layout: makeLayout(),
            windows: [wA, wB],
            screen: makeScreen()
        )
        controller.handleWindowMoved(windowID: 1, currentFrame: slot0Rect)
        let offscreen = CGRect(x: 2000, y: 0, width: 500, height: 800)
        controller.handleWindowMoved(windowID: 1, currentFrame: offscreen)

        XCTAssertNil(controller._testActiveDrag,
                     "center outside every slot's absolute rect must not arm")
    }

    // MARK: - Task 7: finishDrag routes displaced window through sink

    func testFinishDragSwapsTwoWindowsAnimatingDisplaced() {
        let wA = MockWindow(id: 1, frame: slot0Rect)
        let wB = MockWindow(id: 2, frame: slot1Rect)
        let (controller, sink) = makeController(
            layout: makeLayout(),
            windows: [wA, wB],
            screen: makeScreen()
        )
        controller.handleWindowMoved(windowID: 1, currentFrame: slot0Rect)
        controller.handleWindowMoved(windowID: 1, currentFrame: slot0Rect.offsetBy(dx: 400, dy: 0))

        controller.simulateMouseUp()

        XCTAssertEqual(wA.setFrameCallCount, 1)
        XCTAssertEqual(wA.frame, slot1Rect)
        XCTAssertEqual(wB.setFrameCallCount, 0, "displaced window should animate, not setFrame directly")
        XCTAssertEqual(sink.calls.count, 1)
        XCTAssertEqual(sink.calls.first?.windowID, 2)
        XCTAssertEqual(sink.calls.first?.target, slot0Rect)
    }

    /// Regression: in production `AXWindow.frame` reads AX live, so by mouseUp time
    /// `source.frame` reflects the dragged position (≈ targetRect), not the original
    /// slot. An earlier finishDrag implementation inferred sourceOriginalSlotIdx by
    /// rect-matching `source.frame` against slots — that produced the target slot
    /// instead of the original, and the displaced window was animated to where the
    /// source had just landed (visually a no-op). Simulate live AX by `setFrame`-ing
    /// the source between threshold-crossing and mouseUp.
    func testFinishDragWithLiveAXFrameStillSwapsCorrectly() {
        let wA = MockWindow(id: 1, frame: slot0Rect)
        let wB = MockWindow(id: 2, frame: slot1Rect)
        let (controller, sink) = makeController(
            layout: makeLayout(),
            windows: [wA, wB],
            screen: makeScreen()
        )
        controller.handleWindowMoved(windowID: 1, currentFrame: slot0Rect)
        let dragged = slot0Rect.offsetBy(dx: 400, dy: 0)
        controller.handleWindowMoved(windowID: 1, currentFrame: dragged)
        // Mirror what AX would report after the user dragged wA: by mouseUp time the
        // window's live frame is wherever the user dropped it, no longer slot0Rect.
        try? wA.setFrame(dragged)

        controller.simulateMouseUp()

        XCTAssertEqual(wA.frame, slot1Rect, "source still snaps to target slot")
        XCTAssertEqual(sink.calls.count, 1, "displaced window must animate exactly once")
        XCTAssertEqual(sink.calls.first?.windowID, 2, "displaced window is wB")
        XCTAssertEqual(sink.calls.first?.target, slot0Rect,
                       "displaced window must animate to source's ORIGINAL slot — not where source landed")
    }

    func testFinishDragOnEmptyTargetSlotJustSnapsSource() {
        // "Empty target slot" = a slot in the placed layout with no window currently
        // occupying it. We use a 2-slot layout but place only wA (in slot 0), so
        // slot 1 is the empty target. Real scenario: a 4-slot layout fired against
        // 2 windows leaves 2 underflow slots — same outcome (source snaps, no displaced
        // animation) regardless of layout size.
        let wA = MockWindow(id: 1, frame: slot0Rect)
        let (controller, sink) = makeController(
            layout: makeLayout(),
            windows: [wA],
            screen: makeScreen()
        )
        controller.handleWindowMoved(windowID: 1, currentFrame: slot0Rect)
        controller.handleWindowMoved(windowID: 1, currentFrame: slot0Rect.offsetBy(dx: 400, dy: 0))

        controller.simulateMouseUp()

        XCTAssertEqual(wA.frame, slot1Rect)
        XCTAssertEqual(sink.calls.count, 0, "no other window to animate")
    }

    // Stronger self-fire guard test: simulates `WindowAnimator` writing AX frames
    // during the displaced-window animation right after a swap finishes. Those
    // writes fire `kAXMovedNotification` and re-enter `handleWindowMoved`. The
    // guard at gate #2 must reject them because the mouse button is no longer held.
    func testSelfFireDuringDisplacedAnimationDoesNotReEnter() {
        let wA = MockWindow(id: 1, frame: slot0Rect)
        let wB = MockWindow(id: 2, frame: slot1Rect)

        // State-mutable button probe so the test can flip "user released mouse"
        // mid-scenario without rebuilding the controller.
        let pressed = MutableButtonsBox(value: 0b1)
        let sink = RecordingSink()
        let ctx = DragSwapController.Context(
            layout: makeLayout(),
            screen: makeScreen(),
            windows: [wA, wB],
            windowToSlotIdx: [1: 0, 2: 1]
        )
        let controller = DragSwapController(
            contextProvider: { ctx },
            config: { .default },
            animationSink: sink,
            modifierFlagsProbe: { [] },
            mouseButtonsProbe: { pressed.value },
            visibleFrameOverride: { _ in self.vf }
        )

        // 1. Arm + finish a real drag (source = wA, target = slot 1 occupied by wB).
        controller.handleWindowMoved(windowID: 1, currentFrame: slot0Rect)
        controller.handleWindowMoved(windowID: 1, currentFrame: slot0Rect.offsetBy(dx: 400, dy: 0))
        pressed.value = 0  // user releases mouse before mouseUp finishes the swap
        controller.simulateMouseUp()
        XCTAssertEqual(sink.calls.count, 1, "displaced window animated once via sink")

        // 2. Simulate the 3 frames `WindowAnimator` would write to wB during its
        //    250ms easeOut animation. Each fires kAXMovedNotification → re-enters
        //    handleWindowMoved. The mouse-button guard must reject all of them.
        let priorSinkCalls = sink.calls.count
        controller.handleWindowMoved(windowID: 2, currentFrame: slot1Rect.offsetBy(dx: -100, dy: 0))
        controller.handleWindowMoved(windowID: 2, currentFrame: slot1Rect.offsetBy(dx: -300, dy: 0))
        controller.handleWindowMoved(windowID: 2, currentFrame: slot0Rect)

        XCTAssertNil(controller._testActiveDrag,
                     "animator-driven AX writes must not re-arm a swap")
        XCTAssertEqual(sink.calls.count, priorSinkCalls,
                       "no further sink calls — the guard short-circuited each re-entry")
    }

    func testFinishDragWithoutActiveDragIsNoop() {
        let wA = MockWindow(id: 1, frame: slot0Rect)
        let (controller, sink) = makeController(
            layout: makeLayout(),
            windows: [wA],
            screen: makeScreen()
        )
        controller.simulateMouseUp()

        XCTAssertEqual(wA.setFrameCallCount, 0)
        XCTAssertEqual(sink.calls.count, 0)
    }

    // MARK: - Task 8: cancelDrag

    func testCancelDragSnapsSourceBackToOrigin() {
        let wA = MockWindow(id: 1, frame: slot0Rect)
        let wB = MockWindow(id: 2, frame: slot1Rect)
        let (controller, sink) = makeController(
            layout: makeLayout(),
            windows: [wA, wB],
            screen: makeScreen()
        )
        controller.handleWindowMoved(windowID: 1, currentFrame: slot0Rect)
        controller.handleWindowMoved(windowID: 1, currentFrame: slot0Rect.offsetBy(dx: 400, dy: 0))

        controller.cancelDrag()

        XCTAssertEqual(sink.calls.count, 1)
        XCTAssertEqual(sink.calls.first?.windowID, 1)
        XCTAssertEqual(sink.calls.first?.target, slot0Rect,
                       "cancel should snap source back to its origin frame")
        XCTAssertNil(controller._testActiveDrag)
    }

    func testCancelDragWithNoActiveDragIsNoop() {
        let wA = MockWindow(id: 1, frame: slot0Rect)
        let (controller, sink) = makeController(
            layout: makeLayout(),
            windows: [wA],
            screen: makeScreen()
        )
        controller.cancelDrag()

        XCTAssertEqual(sink.calls.count, 0)
    }
}
