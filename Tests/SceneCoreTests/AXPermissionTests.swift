import XCTest
@testable import SceneCore

final class AXPermissionTests: XCTestCase {
    func testCheckDoesNotCrash() {
        _ = AXPermission.check()
    }

    func testSystemSettingsURLIsValid() {
        XCTAssertNotNil(AXPermission.systemSettingsURL)
    }
}
