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
        reopenWelcome: @escaping () -> Void,
        exportDiagnostics: @escaping () async -> Void
    ) {
        self.layoutVM = layoutVM
        self.settingsVM = settingsVM
        self.workspaceVM = workspaceVM
        let host = NSHostingController(
            rootView: SettingsRoot(
                calendarPermissionRequester: calendarPermissionRequester,
                reopenWelcome: reopenWelcome,
                exportDiagnostics: exportDiagnostics
            )
                .environmentObject(layoutVM)
                .environmentObject(settingsVM)
                .environmentObject(workspaceVM)
        )
        let window: NSWindow
        if #available(macOS 26.0, *) {
            // Whole-window translucency. SwiftUI's containerBackground(for:
            // .window) does not bridge into a manually hosted NSWindow, so
            // the material backdrop is an NSVisualEffectView underneath the
            // hosting view; the SwiftUI layer keeps its backgrounds clear
            // (see DetailTabChrome in SettingsRoot).
            let effect = NSVisualEffectView()
            effect.material = .underWindowBackground
            effect.blendingMode = .behindWindow
            effect.state = .followsWindowActiveState
            let container = NSViewController()
            container.view = effect
            container.addChild(host)
            effect.addSubview(host.view)
            host.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                host.view.topAnchor.constraint(equalTo: effect.topAnchor),
                host.view.bottomAnchor.constraint(equalTo: effect.bottomAnchor),
                host.view.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
                host.view.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
            ])
            window = NSWindow(contentViewController: container)
        } else {
            window = NSWindow(contentViewController: host)
        }
        window.setContentSize(NSSize(width: 760, height: 540))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.title = String(localized: "settings.window.title")
        window.isReleasedWhenClosed = false
        if #available(macOS 26.0, *) {
            // Tahoe-style chrome: sidebar glass floats edge-to-edge under a
            // transparent title bar. window.title stays set above for Mission
            // Control / App Exposé / accessibility.
            window.styleMask.insert(.fullSizeContentView)
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
        }
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
