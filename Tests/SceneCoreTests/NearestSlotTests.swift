import XCTest
@testable import SceneCore

final class NearestSlotTests: XCTestCase {
    let vf = CGRect(x: 0, y: 0, width: 1000, height: 1000)

    // Points are in NS coordinates (bottom-left origin): high y = top of screen.
    func testNearestSlotTopLeftInQuads() {
        let idx = nearestSlot(to: CGPoint(x: 100, y: 900), layout: .quads, visibleFrame: vf)
        XCTAssertEqual(idx, 0)
    }

    func testNearestSlotBottomRightInQuads() {
        let idx = nearestSlot(to: CGPoint(x: 900, y: 100), layout: .quads, visibleFrame: vf)
        XCTAssertEqual(idx, 3)
    }

    func testNearestSlotCenterInHalves() {
        let idx = nearestSlot(to: CGPoint(x: 499, y: 500), layout: .halves, visibleFrame: vf)
        XCTAssertEqual(idx, 0)
    }
}
