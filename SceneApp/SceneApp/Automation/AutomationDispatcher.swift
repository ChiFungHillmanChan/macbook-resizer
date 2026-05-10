import Foundation
import SceneCore
import os

/// Single funnel for URL scheme + AppIntents. Owns the Free Mode + AX gates
/// (delegates to `Coordinator.handleAutomationCommand`) and surfaces results
/// as user notifications for the URL-scheme path. AppIntents construct their
/// own `IntentDialog` from the same outcome via `AutomationFeedback`.
@MainActor
final class AutomationDispatcher {

    private let log = Logger(subsystem: "com.scene.app", category: "automation")
    private let coordinator: Coordinator
    private let notifier: NotificationHelper?

    init(coordinator: Coordinator, notifier: NotificationHelper?) {
        self.coordinator = coordinator
        self.notifier = notifier
    }

    /// URL-scheme path: dispatch + surface failure as notification.
    func dispatchFromURL(_ command: AutomationCommand) async {
        let outcome = await coordinator.handleAutomationCommand(command)
        log.info("URL command outcome: \(String(describing: outcome), privacy: .public)")
        if let msg = AutomationFeedback.message(for: outcome) {
            notify(msg)
        }
    }

    /// AppIntent path: returns the outcome so the intent can shape its
    /// `IntentResult` / dialog.
    func dispatchFromIntent(_ command: AutomationCommand) async -> AutomationOutcome {
        let outcome = await coordinator.handleAutomationCommand(command)
        log.info("Intent command outcome: \(String(describing: outcome), privacy: .public)")
        return outcome
    }

    /// Snapshot list of workspace names for `ListWorkspacesIntent`.
    func workspaceNames() async -> [String] {
        let outcome = await coordinator.handleAutomationCommand(.listWorkspaces)
        if case .okWithValue(let names) = outcome { return names }
        return []
    }

    private func notify(_ msg: AutomationFeedback.Message) {
        // Dynamic key: `String.LocalizationValue` bridge is required because
        // `msg.titleKey` / `msg.bodyKey` are runtime Strings. Do not simplify
        // to a bare String literal — the `String(localized:)` overload that
        // accepts a String literal is not the one we want here.
        let title = String(localized: String.LocalizationValue(msg.titleKey))
        let bodyTemplate = String(localized: String.LocalizationValue(msg.bodyKey))
        let body: String
        if let arg = msg.bodyArgument {
            body = String(format: bodyTemplate, arg)
        } else {
            body = bodyTemplate
        }
        notifier?.notify(title: title, body: body)
    }
}
