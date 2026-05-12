import AppIntents
import AppKit
import SceneCore

struct ApplyLayoutIntent: AppIntent {
    static var title: LocalizedStringResource = "Apply Layout"
    static var description = IntentDescription("Apply a Scene layout to windows on the active screen.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Layout")
    var layout: LayoutEntity

    @Parameter(title: "Force (override Free Mode)", default: false)
    var force: Bool

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let dispatcher = (NSApp.delegate as? AppDelegate)?.automationDispatcher else {
            return .result(dialog: "Scene is not ready.")
        }
        let outcome = await dispatcher.dispatchFromIntent(
            .applyLayout(id: .uuid(layout.id), force: force, screen: .underMouse)
        )
        return .result(dialog: dialog(for: outcome, layoutName: layout.name))
    }

    private func dialog(for outcome: AutomationOutcome, layoutName: String) -> IntentDialog {
        switch outcome {
        case .ok:
            return IntentDialog("Applied layout \(layoutName).")
        case .blockedByFreeMode:
            return IntentDialog("Scene is in Free Mode. Toggle the Force option to override.")
        case .blockedByMissingAX:
            return IntentDialog("Scene needs Accessibility permission.")
        case .notFoundLayout(let n), .notFoundWorkspace(let n), .invalidArgument(let n):
            return IntentDialog("Could not apply: \(n).")
        case .okWithValue:
            return IntentDialog("Applied.")
        }
    }
}
