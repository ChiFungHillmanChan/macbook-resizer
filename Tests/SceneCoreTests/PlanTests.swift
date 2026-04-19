import XCTest
@testable import SceneCore

final class PlanTests: XCTestCase {
    func testEmptyPlanIsEmpty() {
        let plan = Plan(placements: [], toMinimize: [], leftEmptySlotCount: 4)
        XCTAssertTrue(plan.isEmpty)
    }

    func testNonEmptyPlan() {
        let plan = Plan(
            placements: [Placement(windowID: 1, targetFrame: .zero)],
            toMinimize: [],
            leftEmptySlotCount: 0
        )
        XCTAssertFalse(plan.isEmpty)
    }
}
