import Foundation

/// Pure mappings from `AutomationOutcome` to user-facing string keys.
/// Lives in SceneCore so it's unit-testable; SceneApp resolves the keys
/// via `String(localized:)` at call time.
public enum AutomationFeedback {

    public struct Message: Equatable, Sendable {
        public let titleKey: String
        public let bodyKey: String
        /// When non-nil, the body string carries a `%@` interpolation slot
        /// that should be replaced with this argument via `String(format:)`.
        public let bodyArgument: String?
    }

    public static func message(for outcome: AutomationOutcome) -> Message? {
        switch outcome {
        case .ok, .okWithValue:
            return nil   // success path — silent
        case .notFoundWorkspace(let name):
            return Message(titleKey: "automation.notify.title",
                           bodyKey: "automation.notify.workspace_not_found",
                           bodyArgument: name)
        case .notFoundLayout(let name):
            return Message(titleKey: "automation.notify.title",
                           bodyKey: "automation.notify.layout_not_found",
                           bodyArgument: name)
        case .blockedByFreeMode:
            return Message(titleKey: "automation.notify.title",
                           bodyKey: "automation.notify.blocked_by_free_mode",
                           bodyArgument: nil)
        case .blockedByMissingAX:
            return Message(titleKey: "automation.notify.title",
                           bodyKey: "automation.notify.blocked_by_missing_ax",
                           bodyArgument: nil)
        case .invalidArgument(let detail):
            return Message(titleKey: "automation.notify.title",
                           bodyKey: "automation.notify.invalid_argument",
                           bodyArgument: detail)
        }
    }
}
