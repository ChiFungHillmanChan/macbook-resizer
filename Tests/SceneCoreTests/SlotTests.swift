import XCTest
@testable import SceneCore

final class SlotTests: XCTestCase {
    func testSlotResolvesToAbsoluteRect() {
        let slot = Slot(rect: CGRect(x: 0, y: 0, width: 0.5, height: 1.0))
        let visibleFrame = CGRect(x: 0, y: 24, width: 1920, height: 1056)
        let absolute = slot.absoluteRect(in: visibleFrame)
        XCTAssertEqual(absolute, CGRect(x: 0, y: 24, width: 960, height: 1056))
    }

    /// Unit rects are authored top-left origin (y=0 = top of screen), matching
    /// the templates, `LayoutNode.flatten`, and every SwiftUI renderer.
    /// `absoluteRect` must flip into NS bottom-left space: a slot at unit y=0
    /// lands at the TOP of the visibleFrame (high NS y), not the bottom.
    func testTopAnchoredUnitRectMaterializesAtNSTop() {
        let top = Slot(rect: CGRect(x: 0, y: 0, width: 1, height: 0.6))
        let visibleFrame = CGRect(x: 0, y: 24, width: 1920, height: 1056)
        let absolute = top.absoluteRect(in: visibleFrame)
        // Top band occupies the UPPER 60% of the visibleFrame in NS coords.
        XCTAssertEqual(absolute.maxY, visibleFrame.maxY, accuracy: 0.001)
        XCTAssertEqual(absolute.height, 0.6 * 1056, accuracy: 0.001)
        XCTAssertEqual(absolute.minY, 24 + 0.4 * 1056, accuracy: 0.001)
    }

    func testBottomAnchoredUnitRectMaterializesAtNSBottom() {
        let bottom = Slot(rect: CGRect(x: 0, y: 0.6, width: 1, height: 0.4))
        let visibleFrame = CGRect(x: 100, y: 50, width: 1000, height: 800)
        let absolute = bottom.absoluteRect(in: visibleFrame)
        XCTAssertEqual(absolute.minY, visibleFrame.minY, accuracy: 0.001)
        XCTAssertEqual(absolute.height, 0.4 * 800, accuracy: 0.001)
    }

    func testSlotRejectsOutOfUnitRect() {
        XCTAssertNil(Slot(safe: CGRect(x: 0, y: 0, width: 1.5, height: 1.0)))
        XCTAssertNotNil(Slot(safe: CGRect(x: 0, y: 0, width: 1.0, height: 1.0)))
    }
}
