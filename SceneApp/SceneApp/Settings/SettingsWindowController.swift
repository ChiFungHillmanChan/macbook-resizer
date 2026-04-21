import AppKit
import SwiftUI

/// Hosts `SettingsRoot` in a real `NSWindow` (rather than a `Settings { }` Scene)
/// so the menu-bar app stays in `.accessory` activation policy by default and
/// only flips to `.regular` while the Settings window is on screen — avoiding a
/// permanent Dock icon for a menu-bar utility.
@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let layoutVM: LayoutStoreViewModel
    private let settingsVM: SettingsStoreViewModel
    private let workspaceVM: WorkspaceStoreViewModel

    init(
        layoutVM: LayoutStoreViewModel,
        settingsVM: SettingsStoreViewModel,
        workspaceVM: WorkspaceStoreViewModel,
        calendarPermissionRequester: @escaping () async -> Bool,
        reopenWelcome: @escaping () -> Void
    ) {
        self.layoutVM = layoutVM
        self.settingsVM = settingsVM
        self.workspaceVM = workspaceVM
        let host = NSHostingController(
            rootView: SettingsRoot(
                calendarPermissionRequester: calendarPermissionRequester,
                reopenWelcome: reopenWelcome
            )
                .environmentObject(layoutVM)
                .environmentObject(settingsVM)
                .environmentObject(workspaceVM)
        )
        let window = NSWindow(contentViewController: host)
        window.setContentSize(NSSize(width: 760, height: 540))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.title = String(localized: "settings.window.title")
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported for SettingsWindowController")
    }

    func show() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    // MARK: NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
