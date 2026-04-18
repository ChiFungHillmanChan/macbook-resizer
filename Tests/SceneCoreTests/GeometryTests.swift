import XCTest
@testable import SceneCore

final class GeometryTests: XCTestCase {
    func testApproxEqualWithinTolerance() {
        let a = CGRect(x: 100, y: 100, width: 500, height: 400)
        let b = CGRect(x: 102, y: 98,  width: 503, height: 396)
        XCTAssertTrue(rectsApproxEqual(a, b, tolerance: 5))
    }

    func testApproxEqualBeyondTolerance() {
        let a = CGRect(x: 100, y: 100, width: 500, height: 400)
        let b = CGRect(x: 100, y: 100, width: 500, height: 394)
        XCTAssertFalse(rectsApproxEqual(a, b, tolerance: 5))
    }

    func testExactEqualAlwaysPasses() {
        let a = CGRect(x: 0, y: 0, width: 100, height: 100)
        XCTAssertTrue(rectsApproxEqual(a, a, tolerance: 0))
    }
}
