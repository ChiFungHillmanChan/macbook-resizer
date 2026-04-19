import XCTest
@testable import SceneCore

final class AnimationConfigTests: XCTestCase {
    func testDefaults() {
        let d = AnimationConfig.default
        XCTAssertTrue(d.enabled)
        XCTAssertEqual(d.durationMs, 250)
        XCTAssertEqual(d.easing, .easeOut)
    }

    func testCodableRoundTrip() throws {
        let original = AnimationConfig(enabled: false, durationMs: 350, easing: .spring)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AnimationConfig.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testClampsDurationOnInit() {
        let low = AnimationConfig(enabled: true, durationMs: 0, easing: .linear)
        XCTAssertEqual(low.durationMs, AnimationConfig.minDurationMs)
        XCTAssertEqual(low.durationMs, 100)

        let high = AnimationConfig(enabled: true, durationMs: 9999, easing: .linear)
        XCTAssertEqual(high.durationMs, AnimationConfig.maxDurationMs)
        XCTAssertEqual(high.durationMs, 500)
    }
}
