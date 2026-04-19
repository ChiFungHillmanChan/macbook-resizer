import XCTest
@testable import SceneCore

final class FocusModeReferenceTests: XCTestCase {
    func testBothFieldsRoundTrip() throws {
        let original = FocusModeReference(shortcutNameOn: "On", shortcutNameOff: "Off")
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FocusModeReference.self, from: encoded)
        XCTAssertEqual(decoded, original)
    }

    func testNilOffRoundTrip() throws {
        let original = FocusModeReference(shortcutNameOn: "OnOnly", shortcutNameOff: nil)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FocusModeReference.self, from: encoded)
        XCTAssertEqual(decoded.shortcutNameOn, "OnOnly")
        XCTAssertNil(decoded.shortcutNameOff)
    }
}
