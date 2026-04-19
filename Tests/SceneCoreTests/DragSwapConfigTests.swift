import XCTest
@testable import SceneCore

final class DragSwapConfigTests: XCTestCase {
    func testDefaults() {
        let d = DragSwapConfig.default
        XCTAssertTrue(d.enabled)
        XCTAssertEqual(d.distanceThresholdPt, 30)
    }

    func testClampsThresholdBelowMinimum() {
        let c = DragSwapConfig(enabled: true, distanceThresholdPt: 5)
        XCTAssertEqual(c.distanceThresholdPt, 10)
    }

    func testClampsThresholdAboveMaximum() {
        let c = DragSwapConfig(enabled: true, distanceThresholdPt: 500)
        XCTAssertEqual(c.distanceThresholdPt, 100)
    }

    func testCodableRoundTrip() throws {
        let original = DragSwapConfig(enabled: false, distanceThresholdPt: 45)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DragSwapConfig.self, from: encoded)
        XCTAssertEqual(decoded, original)
    }

    func testDecodeClampsOutOfRangeValue() throws {
        let json = #"{"enabled":true,"distanceThresholdPt":200}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(DragSwapConfig.self, from: json)
        XCTAssertEqual(decoded.distanceThresholdPt, 100)
    }
}
