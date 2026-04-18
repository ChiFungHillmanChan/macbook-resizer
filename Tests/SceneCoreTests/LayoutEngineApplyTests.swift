import XCTest
@testable import SceneCore

final class LayoutEngineApplyTests: XCTestCase {
    func testApplyEmptyPlanReturnsNoWindows() throws {
        let plan = Plan(placements: [], toMinimize: [], leftEmptySlotCount: 4)
        let outcome = try LayoutEngine.apply(plan, on: [])
        XCTAssertEqual(outcome, .noWindows)
    }

    func testApplyPlacesAndMinimizes() throws {
        let w1 = MockWindow(id: 1)
        let w2 = MockWindow(id: 2)
        let w3 = MockWindow(id: 3)
        let plan = Plan(
            placements: [
                Placement(windowID: 1, targetFrame: CGRect(x: 0,   y: 0, width: 500, height: 1000)),
                Placement(windowID: 2, targetFrame: CGRect(x: 500, y: 0, width: 500, height: 1000)),
            ],
            toMinimize: [3],
            leftEmptySlotCount: 0
        )
        let outcome = try LayoutEngine.apply(plan, on: [w1, w2, w3])
        XCTAssertEqual(outcome, .applied(placed: 2, minimized: 1, leftEmpty: 0, failed: 0))
        XCTAssertEqual(w1.frame, CGRect(x: 0,   y: 0, width: 500, height: 1000))
        XCTAssertEqual(w2.frame, CGRect(x: 500, y: 0, width: 500, height: 1000))
        XCTAssertTrue(w3.isMinimized)
    }

    func testApplyCountsFailures() throws {
        let w1 = MockWindow(id: 1)
        w1.shouldThrowOnSet = true
        let plan = Plan(
            placements: [Placement(windowID: 1, targetFrame: CGRect(x: 0, y: 0, width: 10, height: 10))],
            toMinimize: [],
            leftEmptySlotCount: 0
        )
        let outcome = try LayoutEngine.apply(plan, on: [w1])
        XCTAssertEqual(outcome, .applied(placed: 0, minimized: 0, leftEmpty: 0, failed: 1))
    }
}
