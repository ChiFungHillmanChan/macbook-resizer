import AppKit
import Combine
import SceneCore

/// Orchestrates the 7-step Workspace activation sequence (spec §3.5):
///   1. Quit apps (gentle + 5s grace + notify on survivors)
///   2. Launch apps (parallel)
///   3. Settle 1.5s (new windows appear)
///   4. Apply layout (reuses V0.2 Coordinator.applyLayout)
///   5. Run Focus On shortcut (if set)
///   6. Persist activeWorkspaceID
///   7. Notification banner "已啟動 <name> 情境"
///
/// Interpolated strings use the `String(format: String(localized:), arg)`
/// pattern per Cross-cutting §1 so that zh-HK / en catalog values like
/// `"Activated %@"` / `「已啟動 %@ 情境」` resolve correctly.
@MainActor
final class WorkspaceActivator {
    private let appLauncher: AppLauncher
    private let focusController: FocusController
    private let workspaceStore: WorkspaceStore
    private let layoutStore: LayoutStore
    /// Injected to decouple from Coordinator (avoid circular ownership).
    /// Production wire passes `coordinator.applyLayout`.
    private let applyLayout: (UUID) async -> Void
    private let notifier: NotificationHelper

    init(
        appLauncher: AppLauncher,
        focusController: FocusController,
        workspaceStore: WorkspaceStore,
        layoutStore: LayoutStore,
        applyLayout: @escaping (UUID) async -> Void,
        notifier: NotificationHelper
    ) {
        self.appLauncher = appLauncher
        self.focusController = focusController
        self.workspaceStore = workspaceStore
        self.layoutStore = layoutStore
        self.applyLayout = applyLayout
        self.notifier = notifier
    }

    /// Returns after the Workspace is activated (all async steps complete).
    func activate(workspaceID: UUID) async {
        guard let workspace = workspaceStore.workspaces.first(where: { $0.id == workspaceID }) else {
            NSLog("[Scene] WorkspaceActivator.activate: unknown workspace \(workspaceID)")
            return
        }

        // Previous Workspace's Focus Off (per §4.8: do NOT re-run its appsToQuit).
        if let previous = workspaceStore.activeWorkspaceID,
           previous != workspaceID,
           let previousWorkspace = workspaceStore.workspaces.first(where: { $0.id == previous }) {
            focusController.run(focusMode: previousWorkspace.focusMode, activating: false)
        }

        // 1. Quit (gentle + grace + notify)
        let quitReport = await appLauncher.quit(bundleIDs: workspace.appsToQuit)
        if !quitReport.survivors.isEmpty {
            let names = quitReport.survivors.compactMap { $0.localizedName }.joined(separator: "、")
            notifier.notify(
                title: String(localized: "workspace.quit.partial.title"),
                body: String(format: String(localized: "workspace.quit.partial.body"), names)
            )
        }

        // 2. Launch (parallel)
        await appLauncher.launch(bundleIDs: workspace.appsToLaunch)

        // 3. Settle
        try? await Task.sleep(for: .milliseconds(1500))

        // 4. Apply layout (validate layout still exists; warn if not)
        if layoutStore.layouts.contains(where: { $0.id == workspace.layoutID }) {
            await applyLayout(workspace.layoutID)
        } else {
            notifier.notify(
                title: String(localized: "workspace.missing_layout.title"),
                body: String(format: String(localized: "workspace.missing_layout.body"), workspace.name)
            )
        }

        // 5. Focus On
        focusController.run(focusMode: workspace.focusMode, activating: true)

        // 6. Persist active state
        try? workspaceStore.setActive(workspaceID)

        // 7. Activation banner
        notifier.notify(
            title: String(localized: "workspace.activated.title"),
            body: String(format: String(localized: "workspace.activated.body"), workspace.name)
        )
    }
}
