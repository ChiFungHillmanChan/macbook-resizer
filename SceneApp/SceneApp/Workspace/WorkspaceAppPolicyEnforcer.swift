import AppKit
import SceneCore
import class SceneCore.Cancellable

@MainActor
protocol WorkspaceAppPolicyEnforcing: AnyObject {
    func beginActivation(workspaceID: UUID)
    func finishActivation()
    func enforceActiveWorkspace()
}

@MainActor
final class WorkspaceAppPolicyEnforcer: WorkspaceAppPolicyEnforcing {
    private let workspaceStore: WorkspaceStore
    private var notificationTokens: [NSObjectProtocol] = []
    private var storeToken: Cancellable?
    private var pendingWorkspaceID: UUID?

    init(workspaceStore: WorkspaceStore) {
        self.workspaceStore = workspaceStore
    }

    func start() {
        guard notificationTokens.isEmpty else { return }

        let center = NSWorkspace.shared.notificationCenter
        notificationTokens.append(
            center.addObserver(
                forName: NSWorkspace.didLaunchApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.enforceActiveWorkspace() }
            }
        )
        notificationTokens.append(
            center.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.enforceActiveWorkspace() }
            }
        )
        storeToken = workspaceStore.onChange { [weak self] in
            Task { @MainActor in self?.enforceActiveWorkspace() }
        }
        enforceActiveWorkspace()
    }

    func stop() {
        let center = NSWorkspace.shared.notificationCenter
        notificationTokens.forEach { center.removeObserver($0) }
        notificationTokens = []
        storeToken?.cancel()
        storeToken = nil
        pendingWorkspaceID = nil
    }

    func beginActivation(workspaceID: UUID) {
        pendingWorkspaceID = workspaceID
    }

    func finishActivation() {
        pendingWorkspaceID = nil
        enforceActiveWorkspace()
    }

    func enforceActiveWorkspace() {
        guard let active = activeWorkspace else { return }
        let disallowedBundleIDs = disallowedPinnedAppIDs(for: active)
        guard !disallowedBundleIDs.isEmpty else { return }

        switch active.enforcementMode {
        case .off, .arrangeOnly:
            return
        case .hideWhenInactive:
            for app in matchingRunningApplications(disallowedBundleIDs) where !app.isHidden {
                app.hide()
            }
        case .quitWhenInactive:
            for app in matchingRunningApplications(disallowedBundleIDs) {
                app.terminate()
            }
        }
    }

    private var activeWorkspace: Workspace? {
        let id = pendingWorkspaceID ?? workspaceStore.activeWorkspaceID
        guard let id else { return nil }
        return workspaceStore.workspaces.first { $0.id == id }
    }

    private func disallowedPinnedAppIDs(for active: Workspace) -> Set<String> {
        var disallowed = Set(
            workspaceStore.workspaces
                .filter { $0.id != active.id }
                .flatMap(\.pinnedApps)
        )
        disallowed.subtract(Set(active.pinnedApps))
        if let sceneBundleID = Bundle.main.bundleIdentifier {
            disallowed.remove(sceneBundleID)
        }
        return disallowed
    }

    private func matchingRunningApplications(_ bundleIDs: Set<String>) -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications.filter { app in
            guard let bundleID = app.bundleIdentifier else { return false }
            return bundleIDs.contains(bundleID) && !app.isTerminated
        }
    }

    deinit {
        let center = NSWorkspace.shared.notificationCenter
        notificationTokens.forEach { center.removeObserver($0) }
        storeToken?.cancel()
    }
}
