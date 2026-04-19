import XCTest
@testable import SceneCore

final class LayoutEnginePlanTests: XCTestCase {
    let vf = CGRect(x: 0, y: 0, width: 1000, height: 1000)

    func testExactMatch() {
        let ws = [
            MockWindow(id: 1, frame: CGRect(x: 0,   y: 0, width: 500, height: 500)),
            MockWindow(id: 2, frame: CGRect(x: 500, y: 0, width: 500, height: 500)),
        ]
        let plan = LayoutEngine.plan(windows: ws, visibleFrame: vf, layout: .halves)
        XCTAssertEqual(plan.placements, [
            Placement(windowID: 1, targetFrame: CGRect(x: 0,   y: 0, width: 500, height: 1000)),
            Placement(windowID: 2, targetFrame: CGRect(x: 500, y: 0, width: 500, height: 1000)),
        ])
        XCTAssertTrue(plan.toMinimize.isEmpty)
        XCTAssertEqual(plan.leftEmptySlotCount, 0)
    }

    func testMoreWindowsThanSlots() {
        let ws = (1...5).map { MockWindow(id: CGWindowID($0)) }
        let plan = LayoutEngine.plan(windows: ws, visibleFrame: vf, layout: .thirds)
        XCTAssertEqual(plan.placements.count, 3)
        XCTAssertEqual(plan.placements.map(\.windowID), [1, 2, 3])
        XCTAssertEqual(plan.toMinimize, [4, 5])
        XCTAssertEqual(plan.leftEmptySlotCount, 0)
    }

    func testFewerWindowsThanSlots() {
        let ws = (1...2).map { MockWindow(id: CGWindowID($0)) }
        let plan = LayoutEngine.plan(windows: ws, visibleFrame: vf, layout: .quads)
        XCTAssertEqual(plan.placements.count, 2)
        XCTAssertTrue(plan.toMinimize.isEmpty)
        XCTAssertEqual(plan.leftEmptySlotCount, 2)
    }

    func testZeroWindows() {
        let plan = LayoutEngine.plan(windows: [], visibleFrame: vf, layout: .quads)
        XCTAssertTrue(plan.isEmpty)
        XCTAssertEqual(plan.leftEmptySlotCount, 4)
    }

    func testZOrderFrontmostGoesToSlotOne() {
        let front = MockWindow(id: 99)
        let second = MockWindow(id: 7)
        let plan = LayoutEngine.plan(windows: [front, second], visibleFrame: vf, layout: .halves)
        XCTAssertEqual(plan.placements[0].windowID, 99)
        XCTAssertEqual(plan.placements[0].targetFrame.origin.x, 0)
    }
}
