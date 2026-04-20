import AppKit
import Combine
import SceneCore
import class SceneCore.Cancellable
import protocol SceneCore.WindowRef
import os

/// Disambiguates SceneCore's closure-based `Cancellable` from `Combine.Cancellable`.
/// We can't write `SceneCore.Cancellable` directly because the SceneCore module
/// also declares an enum named `SceneCore`, which shadows the module name in
/// member lookup. The `import class …` form above pulls the concrete class into
/// scope so this typealias resolves unambiguously.
private typealias SceneCancellable = Cancellable

@MainActor
final class Coordinator: ObservableObject {
    @Published private(set) var permissionGranted: Bool = false
    /// Bumps on every `LayoutStore` change so SwiftUI views observing the
    /// coordinator can rebuild even though `layoutStore` itself isn't an
    /// `ObservableObject`.
    @Published private(set) var layoutListVersion: Int = 0

    private let log = Logger(subsystem: "com.scene.app", category: "coordinator")
    private let hotkeyManager = HotkeyManager()
    private let onboarding = OnboardingWindowController()
    private(set) var notification: NotificationHelper?
    private var permissionPoll: Timer?
    private let onPermissionChange: (Bool) -> Void

    let layoutStore: LayoutStore
    let workspaceStore: WorkspaceStore?
    let settingsStore: SettingsStore
    private let animator = WindowAnimator()
    private let observerGroup = AXMoveObserverGroup()
    private lazy var dragSwapSink = DragSwapAnimationSink(animator: animator, settingsStore: settingsStore)
    private lazy var dragSwapController: DragSwapController = makeDragSwapController()
    private var escMonitor: Any?
    private var lastPlacedWindows: [any SceneWindowRef] = []
    private var lastAppliedLayout: Layout?
    private var lastScreen: NSScreen?
    private var lastWindowToSlotIdx: [CGWindowID: Int] = [:]
    /// Disambiguated from `Combine.Cancellable` (which is brought in by
    /// `import Combine` above) — SceneCore ships its own closure-based token.
    private var layoutStoreObserver: SceneCancellable?

    var statusItem: NSStatusItem?

    /// V0.4: set by `AppDelegate` (Block D Task 17) once `WorkspaceStore` and
    /// `WorkspaceActivator` exist. Until then, `applyWorkspace(id:)` no-ops
    /// with a log line. `Coordinator` owns the supervisor so its lifecycle
    /// (start/stop) tracks the app session; the supervisor's own watchers hold
    /// Timer and NotificationCenter observers that are released on `stop()`.
    private(set) var triggerSupervisor: TriggerSupervisor?

    /// Observes the V0.4 `WorkspaceStore` so workspace hotkey bindings flow
    /// through the same `HotkeyManager` that already routes layout chords.
    /// Registered by `AppDelegate` on launch via `configure(workspaceStore:)`.
    private var workspaceStoreObserver: SceneCancellable?

    init(
        layoutStore: LayoutStore,
        workspaceStore: WorkspaceStore? = nil,
        settingsStore: SettingsStore,
        onPermissionChange: @escaping (Bool) -> Void
    ) {
        self.layoutStore = layoutStore
        self.workspaceStore = workspaceStore
        self.settingsStore = settingsStore
        self.onPermissionChange = onPermissionChange
        self.onboarding.onCheck = { [weak self] in
            Task { @MainActor in self?.refreshPermission() }
        }
    }

    func start() {
        // V0.4: apply any new preset seeds that have been added since the user last
        // launched. For V0.1 users on first V0.4 launch, this adds the 3 vertical seeds
        // (⌘⇧8/9/0). For users who previously deleted a V0.1 seed, that seed stays
        // deleted (LayoutStore's `knownSeedUUIDs` tombstone preserves intent).
        do {
            try layoutStore.applyFutureSeeds(candidates: PresetSeeds.all)
        } catch {
            log.error("applyFutureSeeds failed: \(String(describing: error), privacy: .public)")
        }

        self.notification = NotificationHelper { [weak self] in self?.statusItem }
        notification?.requestAuthorizationIfNeeded()
        refreshPermission()
        schedulePermissionPoll()
        layoutStoreObserver = layoutStore.onChange { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.layoutListVersion &+= 1
                self.registerHotkeysFromStore()
            }
        }
        if let workspaceStore {
            workspaceStoreObserver = workspaceStore.onChange { [weak self] in
                Task { @MainActor in self?.registerHotkeysFromStore() }
            }
        }
    }

    func openOnboarding() { onboarding.show() }

    /// Inject the supervisor after `AppDelegate` has constructed both the
    /// `WorkspaceStore` and `WorkspaceActivator`. Starts the supervisor (arming
    /// all 3 watchers) on first call. Idempotent — second call is a no-op.
    func configure(triggerSupervisor supervisor: TriggerSupervisor) {
        guard triggerSupervisor == nil else { return }
        triggerSupervisor = supervisor
        supervisor.start()
    }

    /// Manually activate a Workspace (via hotkey or menu click). Bypasses the
    /// 30s cooldown. No-op with log line if the supervisor has not been wired
    /// yet (Block C runs before Block D's `AppDelegate` wiring).
    @MainActor
    func applyWorkspace(id: UUID) async {
        guard let supervisor = triggerSupervisor else {
            log.info("applyWorkspace: supervisor not configured, dropping \(id.uuidString, privacy: .public)")
            return
        }
        supervisor.activateManually(workspaceID: id)
    }

    /// Returns `true` when the layout was applied (or animation kicked off
    /// successfully). Returns `false` when the call no-op'd for any reason —
    /// missing permission, no windows, enumeration error, or apply throw. The
    /// Bool is consumed by `WorkspaceActivator` so it can skip the success
    /// banner and `setActive` on failure; hotkey/menu callers discard it.
    @discardableResult
    func applyLayout(id: UUID) -> Bool {
        guard let layout = layoutStore.layouts.first(where: { $0.id == id }) else {
            log.error("applyLayout: unknown id \(id.uuidString, privacy: .public)")
            return false
        }
        return applyLayout(layout)
    }

    @discardableResult
    func applyLayout(_ custom: CustomLayout) -> Bool {
        guard permissionGranted else { onboarding.show(); return false }
        let screen = ScreenResolver.activeScreen()
        do {
            let windows = try AXWindowEnumerator.listVisibleWindows(on: screen)
            if windows.isEmpty {
                notification?.notifyNoWindows()
                return false
            }
            let plan = LayoutEngine.plan(
                windows: windows,
                visibleFrame: screen.visibleFrame,
                layout: custom.toLayout()
            )
            let cfg = settingsStore.animation
            let shouldAnimate = cfg.enabled && windows.count <= 6
            if shouldAnimate {
                animator.animate(windows: windows, placements: plan.placements, config: cfg)
                // Animation only covers placements — minimize overflow synchronously.
                if !plan.toMinimize.isEmpty {
                    _ = try LayoutEngine.apply(
                        Plan(placements: [], toMinimize: plan.toMinimize, leftEmptySlotCount: plan.leftEmptySlotCount),
                        on: windows
                    )
                }
            } else {
                _ = try LayoutEngine.apply(plan, on: windows)
            }
            log.info("applied \(custom.name, privacy: .public) animated=\(shouldAnimate)")
            rebuildDragSwapObservers(plan: plan, windows: windows, layout: custom.toLayout(), screen: screen)
            return true
        } catch AXWindowEnumerator.EnumerationError.permissionDenied {
            stopDragSwapInfrastructure()
            setPermission(false)
            onboarding.show()
            return false
        } catch {
            log.error("applyLayout error: \(String(describing: error), privacy: .public)")
            return false
        }
    }

    // MARK: - permission lifecycle

    private func refreshPermission() { setPermission(AXPermission.forceRecheck()) }

    private func setPermission(_ granted: Bool) {
        guard granted != permissionGranted else { return }
        permissionGranted = granted
        onPermissionChange(granted)
        if granted {
            registerHotkeysFromStore()
            onboarding.hide()
        } else {
            hotkeyManager.unregisterAll()
            stopDragSwapInfrastructure()
        }
    }

    private func schedulePermissionPoll() {
        permissionPoll?.invalidate()
        permissionPoll = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshPermission() }
        }
    }

    // MARK: - Hotkey registration (driven by LayoutStore)

    private func registerHotkeysFromStore() {
        guard permissionGranted else { return }
        hotkeyManager.unregisterAll()
        // Track claimed chords to skip any duplicates in the combined set.
        // Cross-store conflicts are already rejected at save time by each
        // store's `hotkeyConflictProbe`; this belt-and-suspenders guard
        // protects against same-store duplicates that would otherwise
        // double-register with `RegisterEventHotKey`.
        var claimedChords: [HotkeyBinding] = []
        func claim(_ chord: HotkeyBinding) -> Bool {
            if claimedChords.contains(where: { $0 == chord }) { return false }
            claimedChords.append(chord)
            return true
        }
        for layout in layoutStore.layouts {
            guard let binding = layout.hotkey, claim(binding) else { continue }
            let captured = layout.id
            hotkeyManager.register(
                uuid: captured,
                keyCode: binding.keyCode,
                modifiers: binding.carbonModifiers,
                handler: { [weak self] in
                    Task { @MainActor in self?.applyLayout(id: captured) }
                }
            )
        }
        if let workspaceStore {
            for workspace in workspaceStore.workspaces {
                guard let binding = workspace.hotkey, claim(binding) else { continue }
                let captured = workspace.id
                hotkeyManager.register(
                    uuid: captured,
                    keyCode: binding.keyCode,
                    modifiers: binding.carbonModifiers,
                    handler: { [weak self] in
                        Task { @MainActor in await self?.applyWorkspace(id: captured) }
                    }
                )
            }
        }
    }

    // MARK: - Drag-to-swap lifecycle

    private func makeDragSwapController() -> DragSwapController {
        DragSwapController(
            contextProvider: { [weak self] in
                guard let self,
                      let layout = self.lastAppliedLayout,
                      let screen = self.lastScreen
                else { return nil }
                return DragSwapController.Context(
                    layout: layout,
                    screen: screen,
                    windows: self.lastPlacedWindows,
                    windowToSlotIdx: self.lastWindowToSlotIdx
                )
            },
            config: { [weak self] in self?.settingsStore.dragSwap ?? .default },
            animationSink: dragSwapSink
        )
    }

    private func startDragSwapInfrastructure() {
        if escMonitor == nil {
            escMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
                if event.keyCode == 53 {
                    Task { @MainActor in self?.dragSwapController.cancelDrag() }
                }
            }
        }
        dragSwapController.start()
    }

    private func stopDragSwapInfrastructure() {
        observerGroup.stopObserving()
        dragSwapController.stop()
        if let escMonitor { NSEvent.removeMonitor(escMonitor) }
        escMonitor = nil
    }

    /// Replace the AX observer set with the windows that were just placed by the
    /// most recent successful `applyLayout`. Either starts the drag-swap infra
    /// (when enabled in settings and there's a non-empty placed set) or stops it.
    private func rebuildDragSwapObservers(plan: Plan, windows: [any SceneWindowRef], layout: Layout, screen: NSScreen) {
        observerGroup.stopObserving()
        lastPlacedWindows = plan.placements.compactMap { p in
            windows.first(where: { $0.id == p.windowID })
        }
        lastAppliedLayout = layout
        lastScreen = screen
        // Snapshot window→slot mapping. Plan.placements is parallel to layout.slots,
        // so index in the array = slot index. finishDrag uses this to recover the
        // dragged window's original slot without trusting AX-live `source.frame`.
        lastWindowToSlotIdx = Dictionary(
            uniqueKeysWithValues: plan.placements.enumerated().map { ($1.windowID, $0) }
        )
        let placedIDs = Set(lastPlacedWindows.map { $0.id })
        guard settingsStore.dragSwap.enabled, !placedIDs.isEmpty else {
            stopDragSwapInfrastructure()
            return
        }
        observerGroup.startObserving(windowIDs: placedIDs) { [weak self] id, frame in
            self?.dragSwapController.handleWindowMoved(windowID: id, currentFrame: frame)
        }
        startDragSwapInfrastructure()
    }

    deinit {
        if let escMonitor { NSEvent.removeMonitor(escMonitor) }
        // Note: triggerSupervisor?.stop() would require @MainActor hop; its
        // watchers also clean up in their own `deinit` via Timer invalidation
        // and NotificationCenter observer removal on `stop()`. AppDelegate's
        // `applicationWillTerminate` (Block D) is the explicit stop hook.
    }
}
