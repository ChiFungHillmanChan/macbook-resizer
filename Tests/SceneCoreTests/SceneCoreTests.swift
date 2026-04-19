import XCTest
@testable import SceneCore

final class SceneCoreTests: XCTestCase {
    func testVersion() {
        XCTAssertEqual(SceneCore.version, "0.1.0")
    }
}
