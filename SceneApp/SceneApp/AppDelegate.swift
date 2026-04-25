import AppKit
import SwiftUI
import Combine
import SceneCore
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    @Published private(set) var permissionGranted: Bool = false

    let layoutStore: LayoutStore
    let workspaceStore: WorkspaceStore
    let settingsStore: SettingsStore

    let layoutVM: LayoutStoreViewModel
    let workspaceVM: WorkspaceStoreViewModel
    let settingsVM: SettingsStoreViewModel

    /// V0.6 diagnostic pipeline. Constructed in `init()` after the support
    /// dir is computed but before stores are wired, so `Coordinator` /
    /// `WorkspaceActivator` / `TriggerSupervisor` can inject the sink.
    let diagnostics: DiagnosticController

    /// V0.4: Coordinator gains a reference to `WorkspaceStore` so its hotkey
    /// registrar can fold Workspace chords into `HotkeyManager` alongside
    /// Layout chords. V0.6: also accepts a `DiagnosticSink`.
    lazy var coordinator: Coordinator = Coordinator(
        layoutStore: layoutStore,
        workspaceStore: workspaceStore,
        settingsStore: settingsStore,
        onPermissionChange: { [weak self] granted in
            DispatchQueue.main.async {
                self?.permissionGranted = granted
            }
        },
        diagnostics: diagnostics.sink
    )

    /// V0.4 app-layer bridges. Constructed lazily — `applicationDidFinishLaunching`
    /// wires them in after `coordinator.start()` so `NotificationHelper` exists.
    private(set) var appLauncher: AppLauncher?
    private(set) var focusController: FocusController?
    private(set) var workspaceActivator: WorkspaceActivator?
    private(set) var triggerSupervisor: TriggerSupervisor?
    private(set) var workspaceAppPolicyEnforcer: WorkspaceAppPolicyEnforcer?

    /// V0.4.2 passive update nudge. `startPeriodicChecks()` wires an immediate
    /// check plus an hourly timer and a wake-from-sleep observer; the actual
    /// GitHub call is rate-limited to once per 24h per device via UserDefaults,
    /// so long-running menu bar instances discover new releases without
    /// requiring a relaunch (V0.5.1). V0.5.5: launch-time check bypasses the
    /// 24h debounce so quit + relaunch sees fresh state.
    let updateChecker = UpdateChecker()

    /// V0.5.6 in-app installer. Downloads the new DMG, verifies signature,
    /// and triggers the helper script that replaces this binary in place
    /// (preserving the TCC `com.apple.macl` xattr so Accessibility survives).
    let updateInstaller = UpdateInstaller()

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
            },
            reopenWelcome: { [weak self] in
                self?.firstLaunchWindow.show()
            },
            exportDiagnostics: { [weak self] in
                await self?.runDiagnosticsExport()
            }
        )
    }()

    /// Presents `NSSavePanel` and runs the V0.6 diagnostic export. No-op
    /// when diagnostics are disabled. Errors are NSLog'd; surfacing them
    /// through the UI is a future polish.
    @MainActor
    private func runDiagnosticsExport() async {
        guard diagnostics.enabled else {
            NSLog("[Scene] runDiagnosticsExport: diagnostics disabled, skipping")
            return
        }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = DiagnosticExporter.defaultFilename()
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.zip]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let exporter = DiagnosticExporter(
            layoutStore: layoutStore,
            workspaceStore: workspaceStore,
            settingsStore: settingsStore,
            controller: diagnostics
        )
        do {
            try await exporter.export(to: url)
            NSLog("[Scene] diagnostics exported to \(url.path)")
            // Reveal the zip in Finder so the user can drag it straight
            // into the GitHub issue we're about to open.
            NSWorkspace.shared.activateFileViewerSelecting([url])
            // Pre-fill a GitHub issue with environment info + zip-attach
            // reminder. The body is plaintext markdown; user reviews
            // everything in their browser before clicking Submit.
            if let issueURL = buildGitHubIssueURL() {
                NSWorkspace.shared.open(issueURL)
            }
        } catch {
            NSLog("[Scene] diagnostics export failed: \(error)")
        }
    }

    /// Builds a pre-filled "new issue" URL on the project's GitHub repo.
    /// Body carries Scene + macOS versions plus the diagnostic bundle's
    /// `hashID` so the maintainer can correlate it with the dropped zip
    /// without revealing the salt.
    @MainActor
    private func buildGitHubIssueURL() -> URL? {
        let bundleVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "?"
        let buildVersion = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "?"
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let hashID = diagnostics.hasher.hashID()

        // Body kept short on purpose. NSWorkspace.open / Launch Services
        // truncates very long URLs (>~1.5 KB) before passing them to the
        // browser, which silently drops the params on long bodies. The
        // detailed privacy explanation lives inside the zip's README.txt.
        let body = """
        **Environment**
        - Scene version: \(bundleVersion) (build \(buildVersion))
        - macOS: \(osVersion)
        - Hash ID: `\(hashID)`

        **What happened?**


        **Steps to reproduce**
        1.

        **Diagnostic bundle**
        Drag the `scene-diagnostics-*.zip` from the Finder window into this issue. The bundle is sanitized — see `README.txt` inside.
        """

        var components = URLComponents(string: "https://github.com/ChiFungHillmanChan/macbook-resizer/issues/new")
        components?.queryItems = [
            URLQueryItem(name: "title", value: "Bug report (Scene v\(bundleVersion))"),
            URLQueryItem(name: "body", value: body),
            URLQueryItem(name: "labels", value: "bug,diagnostics"),
        ]
        return components?.url
    }

    /// One-time welcome window shown on first install. V0.5.4: no longer
    /// gated on Accessibility — the welcome shows on first launch regardless
    /// of permission state, so users who get stuck on AX (e.g. stale TCC from
    /// upgrading an ad-hoc-signed v0.4.x build) still see the introduction.
    /// Gating still lives in `showFirstLaunchWelcomeIfNeeded()`; the
    /// controller itself does not check the UserDefaults flag, so callers
    /// that want to force-show (e.g. the "Show welcome screen again" button
    /// on the About tab) simply call `firstLaunchWindow.show()` directly.
    ///
    /// `afterDismiss` chains the AX prompt — first-time users go welcome →
    /// onboarding without having to fish in the menu bar.
    @MainActor
    private lazy var firstLaunchWindow: FirstLaunchWindowController = {
        let c = FirstLaunchWindowController()
        c.onOpenSettings = { [weak self] in self?.openSettings() }
        c.afterDismiss = { [weak self] in
            self?.openOnboardingIfMissingAX()
        }
        return c
    }()

    /// Returns the Application Support subfolder this build should use.
    /// Default is `Scene`. Builds whose bundle ID ends in `.testing`
    /// (produced by `scripts/build-testing.sh`) get a separate
    /// `Scene-testing` folder so a developer can run the test build
    /// alongside their production install without colliding layouts /
    /// settings / workspaces / diagnostics. Bundle name fallback covers
    /// ad-hoc renames.
    static func applicationSupportFolderName() -> String {
        if let id = Bundle.main.bundleIdentifier, id.hasSuffix(".testing") {
            return "Scene-testing"
        }
        let name = (Bundle.main.infoDictionary?["CFBundleName"] as? String) ?? ""
        if name.lowercased().contains("testing") {
            return "Scene-testing"
        }
        return "Scene"
    }

    override init() {
        let supportDir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent(Self.applicationSupportFolderName(), isDirectory: true)
        let layoutsURL    = supportDir.appendingPathComponent("layouts.json")
        let settingsURL   = supportDir.appendingPathComponent("settings.json")
        let workspacesURL = supportDir.appendingPathComponent("workspaces.json")
        let diagnosticsDir = supportDir.appendingPathComponent("diagnostics", isDirectory: true)
        do {
            // Phase 1 (see Cross-cutting §3): both stores constructed with the
            // default no-op `hotkeyConflictProbe`. The real cross-probes are
            // installed below in `applicationDidFinishLaunching` once both
            // stores exist and can be captured by `[weak]`.
            self.layoutStore    = try LayoutStore(fileURL: layoutsURL)
            self.workspaceStore = try WorkspaceStore(fileURL: workspacesURL)
            self.settingsStore  = try SettingsStore(fileURL: settingsURL)
            // V0.6: diagnostic pipeline. Default ON (M5 wires the toggle).
            self.diagnostics = try DiagnosticController(directory: diagnosticsDir)
        } catch {
            fatalError("Scene: failed to initialize stores at \(supportDir.path): \(error)")
        }
        self.layoutVM    = LayoutStoreViewModel(store: layoutStore)
        self.workspaceVM = WorkspaceStoreViewModel(store: workspaceStore)
        self.settingsVM  = SettingsStoreViewModel(store: settingsStore)
        super.init()
    }

    @MainActor
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

        // V0.6 wire the diagnostics toggle. Persisted preference flowed
        // through `SettingsStore.diagnosticsEnabled`; SettingsStoreViewModel
        // pushes user-driven changes through `onDiagnosticsToggle` so the
        // controller can drain (off) or rebuild (on) its writer.
        settingsVM.onDiagnosticsToggle = { [weak self] enabled in
            guard let self else { return }
            if enabled {
                try? self.diagnostics.enable()
            } else {
                await self.diagnostics.disable()
            }
        }
        // Sync controller state with the persisted setting in case the
        // user toggled off in a previous session — `init` defaulted to
        // ON, so we may need to retroactively disable.
        if !settingsStore.diagnosticsEnabled {
            Task { await diagnostics.disable() }
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
        let desktopSwitcher = DesktopSwitcher()
        let appPolicyEnforcer = WorkspaceAppPolicyEnforcer(workspaceStore: workspaceStore)
        self.appLauncher = launcher
        self.focusController = focus
        self.workspaceAppPolicyEnforcer = appPolicyEnforcer
        appPolicyEnforcer.start()

        let activator = WorkspaceActivator(
            appLauncher: launcher,
            focusController: focus,
            workspaceStore: workspaceStore,
            layoutStore: layoutStore,
            applyLayout: { [weak self] id in
                await MainActor.run {
                    self?.coordinator.applyLayout(id: id, from: .workspace) ?? false
                }
            },
            notifier: notifier,
            desktopSwitcher: desktopSwitcher,
            appPolicyEnforcer: appPolicyEnforcer,
            diagnostics: diagnostics.sink
        )
        self.workspaceActivator = activator

        let supervisor = TriggerSupervisor(
            workspaceStore: workspaceStore,
            activator: activator,
            diagnostics: diagnostics.sink
        )
        self.triggerSupervisor = supervisor
        coordinator.configure(triggerSupervisor: supervisor)

        updateChecker.startPeriodicChecks()

        // V0.5.4: welcome on first launch regardless of AX state. If the
        // welcome did NOT show (returning user with the flag already set)
        // and AX is missing, surface the onboarding window automatically so
        // returning users with a broken TCC grant don't have to discover the
        // hidden "Grant Accessibility" menu item to recover.
        if !showFirstLaunchWelcomeIfNeeded() {
            openOnboardingIfMissingAX()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        workspaceAppPolicyEnforcer?.stop()
        triggerSupervisor?.stop()
    }

    @MainActor
    func openSettings() {
        settingsWindow.show()
    }

    /// Shows the welcome window on the very first launch, regardless of
    /// Accessibility state (V0.5.4). Returns `true` when the welcome was
    /// shown, `false` when the flag was already set and we skipped — the
    /// caller uses the return value to decide whether to also chain the
    /// onboarding window for returning users without AX.
    ///
    /// Flag is set BEFORE showing so a cmd-Q during the welcome does not
    /// cause it to re-appear — preferable to re-showing it indefinitely
    /// until a clean dismiss.
    @MainActor
    @discardableResult
    private func showFirstLaunchWelcomeIfNeeded() -> Bool {
        let key = "hasShownFirstLaunchWelcomeV1"
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: key) { return false }
        defaults.set(true, forKey: key)
        firstLaunchWindow.show()
        return true
    }

    /// Opens the AX onboarding window if Accessibility is currently missing.
    /// Called after the welcome dismisses (first-time users) and from
    /// `applicationDidFinishLaunching` (returning users skipping the welcome).
    /// Uses `forceRecheck()` so a grant made between launch and welcome
    /// dismissal is honored even if the polling timer has not fired yet.
    @MainActor
    private func openOnboardingIfMissingAX() {
        if !AXPermission.forceRecheck() {
            coordinator.openOnboarding()
        }
    }
}
