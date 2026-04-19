import XCTest
import AppKit
import CoreGraphics
@testable import SceneCore
import protocol SceneCore.WindowRef

typealias SceneWindowRef = WindowRef

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
        let ctx = DragSwapController.Context(layout: layout, screen: screen, windows: windows)
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
}
