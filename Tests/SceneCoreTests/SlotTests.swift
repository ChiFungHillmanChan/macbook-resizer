import XCTest
@testable import SceneCore

final class SlotTests: XCTestCase {
    func testSlotResolvesToAbsoluteRect() {
        let slot = Slot(rect: CGRect(x: 0, y: 0, width: 0.5, height: 1.0))
        let visibleFrame = CGRect(x: 0, y: 24, width: 1920, height: 1056)
        let absolute = slot.absoluteRect(in: visibleFrame)
        XCTAssertEqual(absolute, CGRect(x: 0, y: 24, width: 960, height: 1056))
    }

    func testSlotRejectsOutOfUnitRect() {
        XCTAssertNil(Slot(safe: CGRect(x: 0, y: 0, width: 1.5, height: 1.0)))
        XCTAssertNotNil(Slot(safe: CGRect(x: 0, y: 0, width: 1.0, height: 1.0)))
    }
}
