import AppKit
import Combine
import SceneCore
import Carbon.HIToolbox
import os

@MainActor
final class Coordinator: ObservableObject {
    @Published private(set) var permissionGranted: Bool = false

    private let log = Logger(subsystem: "com.scene.app", category: "coordinator")
    private let hotkeyManager = HotkeyManager()
    private let onboarding = OnboardingWindowController()
    private var notification: NotificationHelper?
    private var permissionPoll: Timer?
    private let onPermissionChange: (Bool) -> Void

    var statusItem: NSStatusItem?

    init(onPermissionChange: @escaping (Bool) -> Void) {
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
    }

    func openOnboarding() {
        onboarding.show()
    }

    func applyLayout(_ id: LayoutID) {
        guard permissionGranted else {
            onboarding.show()
            return
        }
        let screen = ScreenResolver.activeScreen()
        do {
            let windows = try AXWindowEnumerator.listVisibleWindows(on: screen)
            let layout = Layout.layout(for: id)
            let plan = LayoutEngine.plan(
                windows: windows,
                visibleFrame: screen.visibleFrame,
                layout: layout
            )
            let outcome = try LayoutEngine.apply(plan, on: windows)
            if case .noWindows = outcome {
                notification?.notifyNoWindows()
            } else {
                log.info("applied \(id.rawValue, privacy: .public) outcome=\(String(describing: outcome), privacy: .public)")
            }
        } catch AXWindowEnumerator.EnumerationError.permissionDenied {
            setPermission(false)
            onboarding.show()
        } catch {
            log.error("applyLayout error: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: - permission lifecycle

    private func refreshPermission() {
        setPermission(AXPermission.check())
    }

    private func setPermission(_ granted: Bool) {
        guard granted != permissionGranted else { return }
        permissionGranted = granted
        onPermissionChange(granted)
        if granted {
            registerHotkeys()
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

    private func registerHotkeys() {
        hotkeyManager.unregisterAll()
        for (layoutID, keyCode) in DefaultHotkeyKeys.mapping {
            let captured = layoutID
            hotkeyManager.register(
                id: captured,
                keyCode: keyCode,
                modifiers: HotkeyModifiers.cmdShift,
                handler: { [weak self] in
                    Task { @MainActor in self?.applyLayout(captured) }
                }
            )
        }
    }
}
