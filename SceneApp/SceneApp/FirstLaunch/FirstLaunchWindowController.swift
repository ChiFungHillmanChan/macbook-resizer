import AppKit
import SwiftUI

/// Owns the `NSWindow` for the one-time welcome screen. Mirrors
/// `OnboardingWindowController` in structure — single window reused across
/// `show()` calls, closable but not released so state survives close/reopen.
///
/// The controller does NOT check the UserDefaults flag itself; gating lives in
/// `AppDelegate.showFirstLaunchWelcomeIfNeeded()`. Callers that want to bypass
/// the gate (e.g. the "Show welcome screen again" button on the About tab)
/// simply call `show()` directly.
@MainActor
final class FirstLaunchWindowController {
    private var window: NSWindow?

    /// Invoked when the user clicks the "Open Settings" button. Wired by
    /// `AppDelegate` to call `openSettings()` so the Settings window opens on
    /// the Workspaces tab.
    var onOpenSettings: () -> Void = {}

    func show() {
        if window == nil {
            let view = FirstLaunchView(
                onDismiss: { [weak self] in self?.hide() },
                onOpenSettings: { [weak self] in
                    self?.hide()
                    self?.onOpenSettings()
                }
            )
            let host = NSHostingController(rootView: view)
            let w = NSWindow(contentViewController: host)
            w.title = String(localized: "welcome.title")
            w.styleMask = [.titled, .closable]
            w.center()
            w.isReleasedWhenClosed = false
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func hide() {
        window?.orderOut(nil)
    }
}
