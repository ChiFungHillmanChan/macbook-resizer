import AppIntents
import AppKit
import SceneCore

struct ActivateWorkspaceIntent: AppIntent {
    static var title: LocalizedStringResource = "Activate Workspace"
    static var description = IntentDescription("Activate a Scene Workspace — launch its apps, apply its layout, set its Focus mode.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Workspace")
    var workspace: WorkspaceEntity

    @Parameter(title: "Force (override Free Mode)", default: false)
    var force: Bool

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let dispatcher = (NSApp.delegate as? AppDelegate)?.automationDispatcher else {
            return .result(dialog: "Scene is not ready.")
        }
        let outcome = await dispatcher.dispatchFromIntent(
            .activateWorkspace(id: .uuid(workspace.id), force: force)
        )
        return .result(dialog: dialog(for: outcome, name: workspace.name))
    }

    private func dialog(for outcome: AutomationOutcome, name: String) -> IntentDialog {
        switch outcome {
        case .ok:
            return IntentDialog("Activated \(name).")
        case .blockedByFreeMode:
            return IntentDialog("Scene is in Free Mode. Toggle the Force option to override.")
        case .blockedByMissingAX:
            return IntentDialog("Scene needs Accessibility permission.")
        case .notFoundWorkspace(let n), .notFoundLayout(let n), .invalidArgument(let n):
            return IntentDialog("Could not activate: \(n).")
        case .okWithValue:
            return IntentDialog("Activated.")
        }
    }
}
