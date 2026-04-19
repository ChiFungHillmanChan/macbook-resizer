import AppKit
import Combine
import SceneCore
import class SceneCore.Cancellable
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
    private var notification: NotificationHelper?
    private var permissionPoll: Timer?
    private let onPermissionChange: (Bool) -> Void

    let layoutStore: LayoutStore
    let settingsStore: SettingsStore
    private let animator = WindowAnimator()
    /// Disambiguated from `Combine.Cancellable` (which is brought in by
    /// `import Combine` above) — SceneCore ships its own closure-based token.
    private var layoutStoreObserver: SceneCancellable?

    var statusItem: NSStatusItem?

    init(
        layoutStore: LayoutStore,
        settingsStore: SettingsStore,
        onPermissionChange: @escaping (Bool) -> Void
    ) {
        self.layoutStore = layoutStore
        self.settingsStore = settingsStore
        self.onPermissionChange = onPermissionChange
        self.onboarding.onCheck = { [weak self] in
            Task { @MainActor in self?.refreshPermission() }
        }
    }

    func start() {
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
    }

    func openOnboarding() { onboarding.show() }

    func applyLayout(id: UUID) {
        guard let layout = layoutStore.layouts.first(where: { $0.id == id }) else {
            log.error("applyLayout: unknown id \(id.uuidString, privacy: .public)")
            return
        }
        applyLayout(layout)
    }

    func applyLayout(_ custom: CustomLayout) {
        guard permissionGranted else { onboarding.show(); return }
        let screen = ScreenResolver.activeScreen()
        do {
            let windows = try AXWindowEnumerator.listVisibleWindows(on: screen)
            if windows.isEmpty {
                notification?.notifyNoWindows()
                return
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
        } catch AXWindowEnumerator.EnumerationError.permissionDenied {
            setPermission(false)
            onboarding.show()
        } catch {
            log.error("applyLayout error: \(String(describing: error), privacy: .public)")
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
        for layout in layoutStore.layouts {
            guard let binding = layout.hotkey else { continue }
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
    }
}
