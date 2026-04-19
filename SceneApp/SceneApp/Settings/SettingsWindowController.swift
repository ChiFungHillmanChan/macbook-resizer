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

    init(layoutVM: LayoutStoreViewModel, settingsVM: SettingsStoreViewModel) {
        self.layoutVM = layoutVM
        self.settingsVM = settingsVM
        let host = NSHostingController(
            rootView: SettingsRoot()
                .environmentObject(layoutVM)
                .environmentObject(settingsVM)
        )
        let window = NSWindow(contentViewController: host)
        window.setContentSize(NSSize(width: 700, height: 500))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.title = "Scene Settings"
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
