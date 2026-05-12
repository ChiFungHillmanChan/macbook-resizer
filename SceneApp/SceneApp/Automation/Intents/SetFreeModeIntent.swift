import AppIntents
import AppKit
import SceneCore

struct SetFreeModeIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Free Mode"
    static var description = IntentDescription("Explicitly set Scene Free Mode on or off.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Enabled")
    var enabled: Bool

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let dispatcher = (NSApp.delegate as? AppDelegate)?.automationDispatcher else {
            return .result(dialog: "Scene is not ready.")
        }
        let outcome = await dispatcher.dispatchFromIntent(.setFreeMode(enabled: enabled))
        switch outcome {
        case .ok:
            return .result(dialog: enabled ? "Free Mode on." : "Free Mode off.")
        default:
            return .result(dialog: "Could not set Free Mode.")
        }
    }
}
