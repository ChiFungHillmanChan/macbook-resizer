import XCTest
@testable import SceneCore

final class LayoutTests: XCTestCase {
    func testAllLayoutsPresent() {
        XCTAssertEqual(Layout.all.count, 7)
        XCTAssertEqual(Layout.all.map(\.id), [
            .full, .halves, .thirds, .quads, .mainSide, .leftSplitRight, .leftRightSplit
        ])
    }

    func testSlotCounts() {
        XCTAssertEqual(Layout.full.slots.count, 1)
        XCTAssertEqual(Layout.halves.slots.count, 2)
        XCTAssertEqual(Layout.thirds.slots.count, 3)
        XCTAssertEqual(Layout.quads.slots.count, 4)
        XCTAssertEqual(Layout.mainSide.slots.count, 2)
        XCTAssertEqual(Layout.leftSplitRight.slots.count, 3)
        XCTAssertEqual(Layout.leftRightSplit.slots.count, 3)
    }

    func testQuadsOnFullHDVisibleFrame() {
        let visibleFrame = CGRect(x: 0, y: 24, width: 1920, height: 1056)
        let rects = Layout.quads.slots.map { $0.absoluteRect(in: visibleFrame) }
        XCTAssertEqual(rects, [
            CGRect(x: 0,   y: 24,       width: 960, height: 528),
            CGRect(x: 960, y: 24,       width: 960, height: 528),
            CGRect(x: 0,   y: 24 + 528, width: 960, height: 528),
            CGRect(x: 960, y: 24 + 528, width: 960, height: 528),
        ])
    }

    func testMainSidePercentage() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1000, height: 1000)
        let rects = Layout.mainSide.slots.map { $0.absoluteRect(in: visibleFrame) }
        XCTAssertEqual(rects[0], CGRect(x: 0,   y: 0, width: 700, height: 1000))
        XCTAssertEqual(rects[1], CGRect(x: 700, y: 0, width: 300, height: 1000))
    }
}
