import AppIntents
import AppKit
import SceneCore

struct ToggleFreeModeIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Free Mode"
    static var description = IntentDescription("Toggle Scene Free Mode — pauses or resumes all automatic Scene behavior.")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let dispatcher = (NSApp.delegate as? AppDelegate)?.automationDispatcher else {
            return .result(dialog: "Scene is not ready.")
        }
        let outcome = await dispatcher.dispatchFromIntent(.toggleFreeMode)
        let isOn = (NSApp.delegate as? AppDelegate)?.coordinator.freeMode ?? false
        switch outcome {
        case .ok:
            return .result(dialog: isOn ? "Free Mode on." : "Free Mode off.")
        default:
            return .result(dialog: "Could not toggle Free Mode.")
        }
    }
}
