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
    /// Production wire passes `coordinator.applyLayout`. Returns `true` when
    /// the layout was actually applied — the activator uses this to decide
    /// whether to show the success banner and persist `activeWorkspaceID`.
    private let applyLayout: (UUID) async -> Bool
    private let notifier: NotificationHelper
    private let desktopSwitcher: DesktopSwitching?
    private weak var appPolicyEnforcer: WorkspaceAppPolicyEnforcing?

    private let diagnostics: DiagnosticSink

    init(
        appLauncher: AppLauncher,
        focusController: FocusController,
        workspaceStore: WorkspaceStore,
        layoutStore: LayoutStore,
        applyLayout: @escaping (UUID) async -> Bool,
        notifier: NotificationHelper,
        desktopSwitcher: DesktopSwitching? = nil,
        appPolicyEnforcer: WorkspaceAppPolicyEnforcing? = nil,
        diagnostics: DiagnosticSink = .noop
    ) {
        self.appLauncher = appLauncher
        self.focusController = focusController
        self.workspaceStore = workspaceStore
        self.layoutStore = layoutStore
        self.applyLayout = applyLayout
        self.notifier = notifier
        self.desktopSwitcher = desktopSwitcher
        self.appPolicyEnforcer = appPolicyEnforcer
        self.diagnostics = diagnostics
    }

    /// Returns after the Workspace is activated (all async steps complete).
    func activate(workspaceID: UUID) async {
        guard let workspace = workspaceStore.workspaces.first(where: { $0.id == workspaceID }) else {
            NSLog("[Scene] WorkspaceActivator.activate: unknown workspace \(workspaceID)")
            return
        }

        appPolicyEnforcer?.beginActivation(workspaceID: workspaceID)
        defer { appPolicyEnforcer?.finishActivation() }

        // Previous Workspace's Focus Off (per §4.8: do NOT re-run its appsToQuit).
        if let previous = workspaceStore.activeWorkspaceID,
           previous != workspaceID,
           let previousWorkspace = workspaceStore.workspaces.first(where: { $0.id == previous }) {
            focusController.run(focusMode: previousWorkspace.focusMode, activating: false)
        }

        // 1. Quit (gentle + grace + notify)
        let quitStart = Date()
        let quitReport = await appLauncher.quit(bundleIDs: workspace.appsToQuit)
        diagnostics.log(.workspaceStep(.init(
            workspaceID: workspaceID, step: .quit,
            status: quitReport.survivors.isEmpty ? .ok : .failure,
            durationMs: Int(Date().timeIntervalSince(quitStart) * 1000),
            appCount: workspace.appsToQuit.count,
            survivorCount: quitReport.survivors.count
        )))
        if !quitReport.survivors.isEmpty {
            let names = quitReport.survivors.compactMap { $0.localizedName }.joined(separator: "、")
            notifier.notify(
                title: String(localized: "workspace.quit.partial.title"),
                body: String(format: String(localized: "workspace.quit.partial.body"), names)
            )
        }

        if let desktop = workspace.assignedDesktop {
            let switched = await desktopSwitcher?.switchToDesktop(desktop) ?? false
            if !switched {
                NSLog("[Scene] WorkspaceActivator.activate: failed to switch to Desktop \(desktop)")
            }
        }

        // 2. Launch (parallel)
        let launchIDs = uniqueAppIDs(workspace.pinnedApps + workspace.appsToLaunch)
        let launchStart = Date()
        await appLauncher.launch(bundleIDs: launchIDs)
        diagnostics.log(.workspaceStep(.init(
            workspaceID: workspaceID, step: .launch, status: .ok,
            durationMs: Int(Date().timeIntervalSince(launchStart) * 1000),
            appCount: launchIDs.count
        )))

        // 3. Settle — only when we actually launched something that may still
        // be registering its first windows. Skipping the 1.5s delay on empty
        // lists (typical for default seeded Workspaces) keeps menu-click
        // feedback near-instant.
        if !launchIDs.isEmpty {
            try? await Task.sleep(for: .milliseconds(1500))
            diagnostics.log(.workspaceStep(.init(
                workspaceID: workspaceID, step: .settle, status: .ok,
                durationMs: 1500, appCount: launchIDs.count
            )))
        } else {
            diagnostics.log(.workspaceStep(.init(
                workspaceID: workspaceID, step: .settle, status: .skipped,
                durationMs: 0
            )))
        }

        // 4. Apply layout (validate layout still exists; warn if not).
        // On failure, skip steps 6/7 so we don't falsely banner "Activated"
        // or persist `activeWorkspaceID` when no windows were placed. Focus
        // (step 5) still runs — it's independent of layout state and the
        // user explicitly opted in to the Shortcut.
        let layoutApplied: Bool
        let applyStart = Date()
        if layoutStore.layouts.contains(where: { $0.id == workspace.layoutID }) {
            layoutApplied = await applyLayout(workspace.layoutID)
            if !layoutApplied {
                notifier.notify(
                    title: String(localized: "workspace.apply_failed.title"),
                    body: String(format: String(localized: "workspace.apply_failed.body"), workspace.name)
                )
            }
        } else {
            layoutApplied = false
            notifier.notify(
                title: String(localized: "workspace.missing_layout.title"),
                body: String(format: String(localized: "workspace.missing_layout.body"), workspace.name)
            )
        }
        diagnostics.log(.workspaceStep(.init(
            workspaceID: workspaceID, step: .applyLayout,
            status: layoutApplied ? .ok : .failure,
            durationMs: Int(Date().timeIntervalSince(applyStart) * 1000)
        )))

        // 5. Focus On
        focusController.run(focusMode: workspace.focusMode, activating: true)
        diagnostics.log(.workspaceStep(.init(
            workspaceID: workspaceID, step: .focusOn,
            status: workspace.focusMode == nil ? .skipped : .ok,
            durationMs: 0
        )))

        guard layoutApplied else { return }

        // 6. Persist active state
        try? workspaceStore.setActive(workspaceID)
        diagnostics.log(.workspaceStep(.init(
            workspaceID: workspaceID, step: .setActive, status: .ok, durationMs: 0
        )))

        // 7. Activation banner
        notifier.notify(
            title: String(localized: "workspace.activated.title"),
            body: String(format: String(localized: "workspace.activated.body"), workspace.name)
        )
        diagnostics.log(.workspaceStep(.init(
            workspaceID: workspaceID, step: .banner, status: .ok, durationMs: 0
        )))
    }

    private func uniqueAppIDs(_ bundleIDs: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for id in bundleIDs where !seen.contains(id) {
            seen.insert(id)
            result.append(id)
        }
        return result
    }
}
