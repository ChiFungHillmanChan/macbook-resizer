import XCTest
import AppKit
import CoreGraphics
@testable import SceneCore
import protocol SceneCore.WindowRef

@MainActor
final class SeamResizeControllerTests: XCTestCase {
    /// Standard 1000×800 visibleFrame at origin (0, 0). Matches LayoutReflowTests.
    let vf = CGRect(x: 0, y: 0, width: 1000, height: 800)

    func makeScreen() -> NSScreen { NSScreen.screens[0] }

    func makeController(
        ctx: SeamResizeController.Context?,
        config: DragSwapConfig = .default,
        modifierFlags: NSEvent.ModifierFlags = [],
        pressedButtons: Int = 0b1
    ) -> SeamResizeController {
        SeamResizeController(
            contextProvider: { ctx },
            config: { config },
            modifierFlagsProbe: { modifierFlags },
            mouseButtonsProbe: { pressedButtons },
            visibleFrameOverride: { _ in self.vf }
        )
    }

    func makeTwoColContext(proportions: [Double] = [0.5]) -> (SeamResizeController.Context, MockWindow, MockWindow) {
        let w0 = MockWindow(id: 100, frame: CGRect(x: 0, y: 0, width: 500, height: 800))
        let w1 = MockWindow(id: 101, frame: CGRect(x: 500, y: 0, width: 500, height: 800))
        let ctx = SeamResizeController.Context(
            template: .twoCol,
            proportions: proportions,
            screen: makeScreen(),
            windows: [w0, w1],
            windowToSlotIdx: [100: 0, 101: 1]
        )
        return (ctx, w0, w1)
    }

    // MARK: - Core reflow behavior

    func testTwoColLeftWindowShrunkResizesRightWindow() {
        let (ctx, w0, w1) = makeTwoColContext()
        let controller = makeController(ctx: ctx)

        // User drags w0's right edge to x=400 (40%). Expect w1 repositioned.
        controller.handleWindowResized(
            windowID: w0.id,
            newFrame: CGRect(x: 0, y: 0, width: 400, height: 800)
        )

        XCTAssertEqual(w0.setFrameCallCount, 0, "initiating window must not be written to")
        XCTAssertEqual(w1.setFrameCallCount, 1)
        XCTAssertEqual(w1.frame, CGRect(x: 400, y: 0, width: 600, height: 800))
    }

    func testTwoColRightWindowShrunkResizesLeftWindow() {
        let (ctx, w0, w1) = makeTwoColContext()
        let controller = makeController(ctx: ctx)

        // User drags w1's left edge to x=600 (seam moves right to 60%).
        controller.handleWindowResized(
            windowID: w1.id,
            newFrame: CGRect(x: 600, y: 0, width: 400, height: 800)
        )

        XCTAssertEqual(w1.setFrameCallCount, 0)
        XCTAssertEqual(w0.setFrameCallCount, 1)
        XCTAssertEqual(w0.frame, CGRect(x: 0, y: 0, width: 600, height: 800))
    }

    // MARK: - Self-fire guards

    func testDisabledConfigShortCircuits() {
        let (ctx, w0, w1) = makeTwoColContext()
        let controller = makeController(
            ctx: ctx,
            config: DragSwapConfig(enabled: false, distanceThresholdPt: 30)
        )
        controller.handleWindowResized(
            windowID: w0.id,
            newFrame: CGRect(x: 0, y: 0, width: 400, height: 800)
        )
        XCTAssertEqual(w0.setFrameCallCount, 0)
        XCTAssertEqual(w1.setFrameCallCount, 0)
    }

    func testMouseNotHeldShortCircuits() {
        let (ctx, w0, w1) = makeTwoColContext()
        let controller = makeController(ctx: ctx, pressedButtons: 0)

        controller.handleWindowResized(
            windowID: w0.id,
            newFrame: CGRect(x: 0, y: 0, width: 400, height: 800)
        )
        XCTAssertEqual(w0.setFrameCallCount, 0)
        XCTAssertEqual(w1.setFrameCallCount, 0)
    }

    func testOptionHeldShortCircuits() {
        // Matches DragSwapController's convention: option = "let the OS do its
        // native resize, don't reflow".
        let (ctx, w0, w1) = makeTwoColContext()
        let controller = makeController(ctx: ctx, modifierFlags: .option)

        controller.handleWindowResized(
            windowID: w0.id,
            newFrame: CGRect(x: 0, y: 0, width: 400, height: 800)
        )
        XCTAssertEqual(w0.setFrameCallCount, 0)
        XCTAssertEqual(w1.setFrameCallCount, 0)
    }

    func testEventsFromNonInitiatingWindowIgnored() {
        // First event: w0 resized — claims w0 as initiating. Second event: w1
        // resized (would be our own setFrame echo in practice). Must be ignored.
        let (ctx, w0, w1) = makeTwoColContext()
        let controller = makeController(ctx: ctx)

        controller.handleWindowResized(
            windowID: w0.id,
            newFrame: CGRect(x: 0, y: 0, width: 400, height: 800)
        )
        XCTAssertEqual(w1.setFrameCallCount, 1)
        // Echoed event from w1 — should NOT trigger another reflow cycle.
        controller.handleWindowResized(
            windowID: w1.id,
            newFrame: CGRect(x: 400, y: 0, width: 600, height: 800)
        )
        XCTAssertEqual(w0.setFrameCallCount, 0, "initiating window untouched")
        XCTAssertEqual(w1.setFrameCallCount, 1, "echo from w1 must be ignored")
    }

    // MARK: - Unsupported templates

    func testGrid2x2TemplateDoesNothing() {
        let w0 = MockWindow(id: 200, frame: CGRect(x: 0, y: 0, width: 500, height: 400))
        let w1 = MockWindow(id: 201, frame: CGRect(x: 500, y: 0, width: 500, height: 400))
        let w2 = MockWindow(id: 202, frame: CGRect(x: 0, y: 400, width: 500, height: 400))
        let w3 = MockWindow(id: 203, frame: CGRect(x: 500, y: 400, width: 500, height: 400))
        let ctx = SeamResizeController.Context(
            template: .grid2x2,
            proportions: [0.5, 0.5],
            screen: makeScreen(),
            windows: [w0, w1, w2, w3],
            windowToSlotIdx: [200: 0, 201: 1, 202: 2, 203: 3]
        )
        let controller = makeController(ctx: ctx)
        controller.handleWindowResized(
            windowID: w0.id,
            newFrame: CGRect(x: 0, y: 0, width: 400, height: 400)
        )
        XCTAssertEqual(w0.setFrameCallCount, 0)
        XCTAssertEqual(w1.setFrameCallCount, 0)
        XCTAssertEqual(w2.setFrameCallCount, 0)
        XCTAssertEqual(w3.setFrameCallCount, 0)
    }

    func testSingleTemplateDoesNothing() {
        let w0 = MockWindow(id: 300, frame: CGRect(x: 0, y: 0, width: 1000, height: 800))
        let ctx = SeamResizeController.Context(
            template: .single,
            proportions: [],
            screen: makeScreen(),
            windows: [w0],
            windowToSlotIdx: [300: 0]
        )
        let controller = makeController(ctx: ctx)
        controller.handleWindowResized(
            windowID: w0.id,
            newFrame: CGRect(x: 0, y: 0, width: 500, height: 800)
        )
        XCTAssertEqual(w0.setFrameCallCount, 0)
    }

    // MARK: - Context edge cases

    func testNilContextShortCircuits() {
        let controller = makeController(ctx: nil)
        // Should not crash when no context is available (pre-applyLayout case).
        controller.handleWindowResized(
            windowID: 999,
            newFrame: CGRect(x: 0, y: 0, width: 500, height: 800)
        )
    }

    func testUnknownWindowShortCircuits() {
        let (ctx, w0, w1) = makeTwoColContext()
        let controller = makeController(ctx: ctx)
        // Event from a window not in windowToSlotIdx (e.g., a window that
        // appeared after applyLayout was snapshotted).
        controller.handleWindowResized(
            windowID: 999,
            newFrame: CGRect(x: 0, y: 0, width: 400, height: 800)
        )
        XCTAssertEqual(w0.setFrameCallCount, 0)
        XCTAssertEqual(w1.setFrameCallCount, 0)
    }

    // MARK: - threeCol reflow smoke

    func testThreeColMiddleSlotRightSeamReflowsRightmostWindow() {
        let w0 = MockWindow(id: 400, frame: CGRect(x: 0,      y: 0, width: 333,  height: 800))
        let w1 = MockWindow(id: 401, frame: CGRect(x: 333,    y: 0, width: 333,  height: 800))
        let w2 = MockWindow(id: 402, frame: CGRect(x: 666,    y: 0, width: 334,  height: 800))
        let ctx = SeamResizeController.Context(
            template: .threeCol,
            proportions: [1.0/3.0, 2.0/3.0],
            screen: makeScreen(),
            windows: [w0, w1, w2],
            windowToSlotIdx: [400: 0, 401: 1, 402: 2]
        )
        let controller = makeController(ctx: ctx)

        // User drags w1's right edge out to x=800 (right seam moves). Left edge stays.
        controller.handleWindowResized(
            windowID: w1.id,
            newFrame: CGRect(x: 333, y: 0, width: 467, height: 800)
        )

        XCTAssertEqual(w1.setFrameCallCount, 0, "initiating window untouched")
        // w0 stays in its slot (p[0]=1/3 unchanged) — slot rect identical to before.
        XCTAssertEqual(w0.setFrameCallCount, 1)
        // w2 should slide right: new p[1] = 0.8 → slot x=800, width=200.
        XCTAssertEqual(w2.setFrameCallCount, 1)
        XCTAssertEqual(w2.frame.minX, 800, accuracy: 1)
        XCTAssertEqual(w2.frame.width, 200, accuracy: 1)
    }

    // MARK: - state reset on simulated mouse up (DEBUG helper)

    func testMouseUpClearsActiveInitiatingID() {
        let (ctx, w0, _) = makeTwoColContext()
        let controller = makeController(ctx: ctx)
        controller.handleWindowResized(
            windowID: w0.id,
            newFrame: CGRect(x: 0, y: 0, width: 400, height: 800)
        )
        XCTAssertEqual(controller._testActiveInitiatingID, w0.id)
        controller._testSimulateMouseUp()
        XCTAssertNil(controller._testActiveInitiatingID)
    }
}
