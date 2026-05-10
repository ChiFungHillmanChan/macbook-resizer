import XCTest
@testable import SceneCore

final class AutomationCommandTests: XCTestCase {

    func testApplyLayoutEquatable_byUUID() {
        let id = UUID()
        let a: AutomationCommand = .applyLayout(id: .uuid(id), force: false, screen: .underMouse)
        let b: AutomationCommand = .applyLayout(id: .uuid(id), force: false, screen: .underMouse)
        XCTAssertEqual(a, b)
    }

    func testApplyLayoutNotEqual_whenForceDiffers() {
        let id = UUID()
        let a: AutomationCommand = .applyLayout(id: .uuid(id), force: true, screen: .underMouse)
        let b: AutomationCommand = .applyLayout(id: .uuid(id), force: false, screen: .underMouse)
        XCTAssertNotEqual(a, b)
    }

    func testActivateWorkspace_byNameRoundTrip() {
        let a: AutomationCommand = .activateWorkspace(id: .name("Coding"), force: false)
        let b: AutomationCommand = .activateWorkspace(id: .name("Coding"), force: false)
        XCTAssertEqual(a, b)
    }

    func testIdentifierVariantsNotEqual() {
        let id = UUID()
        let byUUID: WorkspaceIdentifier = .uuid(id)
        let byName: WorkspaceIdentifier = .name(id.uuidString)
        XCTAssertNotEqual(byUUID, byName)
    }

    func testScreenSelector_indexedNotEqualToUnderMouse() {
        XCTAssertNotEqual(ScreenSelector.underMouse, ScreenSelector.index(0))
        XCTAssertNotEqual(ScreenSelector.underMouse, ScreenSelector.primary)
    }
}
