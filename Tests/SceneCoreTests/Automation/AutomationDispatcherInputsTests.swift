import XCTest
@testable import SceneCore

final class AutomationDispatcherInputsTests: XCTestCase {

    func testOK_returnsNoMessage() {
        XCTAssertNil(AutomationFeedback.message(for: .ok))
        XCTAssertNil(AutomationFeedback.message(for: .okWithValue([])))
    }

    func testWorkspaceNotFound_carriesNameArgument() {
        let m = AutomationFeedback.message(for: .notFoundWorkspace("Coding"))
        XCTAssertEqual(m?.bodyKey, "automation.notify.workspace_not_found")
        XCTAssertEqual(m?.bodyArgument, "Coding")
    }

    func testLayoutNotFound_carriesNameArgument() {
        let m = AutomationFeedback.message(for: .notFoundLayout("Halves"))
        XCTAssertEqual(m?.bodyKey, "automation.notify.layout_not_found")
        XCTAssertEqual(m?.bodyArgument, "Halves")
    }

    func testBlockedByFreeMode_noArgument() {
        let m = AutomationFeedback.message(for: .blockedByFreeMode)
        XCTAssertEqual(m?.bodyKey, "automation.notify.blocked_by_free_mode")
        XCTAssertNil(m?.bodyArgument)
    }

    func testBlockedByMissingAX_noArgument() {
        let m = AutomationFeedback.message(for: .blockedByMissingAX)
        XCTAssertEqual(m?.bodyKey, "automation.notify.blocked_by_missing_ax")
    }
}
