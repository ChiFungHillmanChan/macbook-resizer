import AppKit
import SwiftUI
import Combine
import SceneCore

final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    @Published private(set) var permissionGranted: Bool = false

    let layoutStore: LayoutStore
    let workspaceStore: WorkspaceStore
    let settingsStore: SettingsStore

    let layoutVM: LayoutStoreViewModel
    let workspaceVM: WorkspaceStoreViewModel
    let settingsVM: SettingsStoreViewModel

    /// V0.4: Coordinator gains a reference to `WorkspaceStore` so its hotkey
    /// registrar can fold Workspace chords into `HotkeyManager` alongside
    /// Layout chords.
    lazy var coordinator: Coordinator = Coordinator(
        layoutStore: layoutStore,
        workspaceStore: workspaceStore,
        settingsStore: settingsStore,
        onPermissionChange: { [weak self] granted in
            DispatchQueue.main.async {
                self?.permissionGranted = granted
                if granted { self?.showFirstLaunchWelcomeIfNeeded() }
            }
        }
    )

    /// V0.4 app-layer bridges. Constructed lazily — `applicationDidFinishLaunching`
    /// wires them in after `coordinator.start()` so `NotificationHelper` exists.
    private(set) var appLauncher: AppLauncher?
    private(set) var focusController: FocusController?
    private(set) var workspaceActivator: WorkspaceActivator?
    private(set) var triggerSupervisor: TriggerSupervisor?

    /// V0.4.2 passive update nudge. `startPeriodicChecks()` wires an immediate
    /// check plus an hourly timer and a wake-from-sleep observer; the actual
    /// GitHub call is rate-limited to once per 24h per device via UserDefaults,
    /// so long-running menu bar instances discover new releases without
    /// requiring a relaunch (V0.5.1).
    let updateChecker = UpdateChecker()

    /// Single shared instance — re-shown on subsequent "Settings…" clicks
    /// rather than recreated, so view-model state survives close/reopen.
    @MainActor
    private lazy var settingsWindow: SettingsWindowController = {
        SettingsWindowController(
            layoutVM: layoutVM,
            settingsVM: settingsVM,
            workspaceVM: workspaceVM,
            calendarPermissionRequester: { [weak self] in
                guard let watcher = self?.triggerSupervisor?.calendar else { return false }
                return await watcher.requestAccess()
            }
        )
    }()

    /// One-time welcome window shown on first install (after AX is granted).
    /// Gating lives in `showFirstLaunchWelcomeIfNeeded()`; the controller
    /// itself does not check the UserDefaults flag, so callers that want to
    /// force-show (e.g. the "Show welcome screen again" button on the About
    /// tab) simply call `firstLaunchWindow.show()` directly.
    @MainActor
    lazy var firstLaunchWindow: FirstLaunchWindowController = {
        let c = FirstLaunchWindowController()
        c.onOpenSettings = { [weak self] in self?.openSettings() }
        return c
    }()

    override init() {
        let supportDir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Scene", isDirectory: true)
        let layoutsURL    = supportDir.appendingPathComponent("layouts.json")
        let settingsURL   = supportDir.appendingPathComponent("settings.json")
        let workspacesURL = supportDir.appendingPathComponent("workspaces.json")
        do {
            // Phase 1 (see Cross-cutting §3): both stores constructed with the
            // default no-op `hotkeyConflictProbe`. The real cross-probes are
            // installed below in `applicationDidFinishLaunching` once both
            // stores exist and can be captured by `[weak]`.
            self.layoutStore    = try LayoutStore(fileURL: layoutsURL)
            self.workspaceStore = try WorkspaceStore(fileURL: workspacesURL)
            self.settingsStore  = try SettingsStore(fileURL: settingsURL)
        } catch {
            fatalError("Scene: failed to initialize stores at \(supportDir.path): \(error)")
        }
        self.layoutVM    = LayoutStoreViewModel(store: layoutStore)
        self.workspaceVM = WorkspaceStoreViewModel(store: workspaceStore)
        self.settingsVM  = SettingsStoreViewModel(store: settingsStore)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Phase 2 (see Cross-cutting §3): now that both stores exist, install
        // the cross-store hotkey conflict probes. Each probe captures the
        // OPPOSITE store by `[weak]` — strong captures would be safe here too
        // (stores outlive the AppDelegate and AppDelegate outlives the
        // process), but `[weak]` keeps the dependency graph symmetric and
        // matches the plan's locked approach.
        layoutStore.setHotkeyConflictProbe { [weak workspaceStore] chord in
            workspaceStore?.workspaces.first(where: { $0.hotkey == chord })?.name
        }
        workspaceStore.setHotkeyConflictProbe { [weak layoutStore] chord in
            layoutStore?.layouts.first(where: { $0.hotkey == chord })?.name
        }

        // Starts permission polling + notification helper + hotkey registrar.
        coordinator.start()

        // Wire V0.4 app-layer bridges. NotificationHelper lives on the
        // Coordinator and is created in `start()`, so this chain runs
        // strictly after `coordinator.start()`.
        guard let notifier = coordinator.notification else {
            NSLog("[Scene] AppDelegate: NotificationHelper missing after coordinator.start()")
            return
        }
        let launcher = AppLauncher()
        let focus = FocusController()
        self.appLauncher = launcher
        self.focusController = focus

        let activator = WorkspaceActivator(
            appLauncher: launcher,
            focusController: focus,
            workspaceStore: workspaceStore,
            layoutStore: layoutStore,
            applyLayout: { [weak self] id in
                await MainActor.run { self?.coordinator.applyLayout(id: id) ?? false }
            },
            notifier: notifier
        )
        self.workspaceActivator = activator

        let supervisor = TriggerSupervisor(
            workspaceStore: workspaceStore,
            activator: activator
        )
        self.triggerSupervisor = supervisor
        coordinator.configure(triggerSupervisor: supervisor)

        updateChecker.startPeriodicChecks()

        showFirstLaunchWelcomeIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        triggerSupervisor?.stop()
    }

    @MainActor
    func openSettings() {
        settingsWindow.show()
    }

    /// Shows the welcome window the very first time AX permission is both
    /// granted and detected. Flag is set BEFORE showing so a cmd-Q during the
    /// welcome does not cause it to re-appear — preferable to re-showing it
    /// indefinitely until a clean dismiss.
    ///
    /// Idempotent — safe to call multiple times. Called from
    /// `applicationDidFinishLaunching` (covers the AX-already-granted case)
    /// and from the permission-change closure (covers the grant-during-session
    /// case).
    @MainActor
    private func showFirstLaunchWelcomeIfNeeded() {
        let key = "hasShownFirstLaunchWelcomeV1"
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: key) { return }
        guard permissionGranted else { return }
        defaults.set(true, forKey: key)
        firstLaunchWindow.show()
    }
}
