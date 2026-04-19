import AppKit
import SceneCore

/// Runs a macOS Shortcuts workflow by name via the `shortcuts://` URL scheme.
/// Fire-and-forget: Scene does not await or inspect the result. If the shortcut
/// doesn't exist, nothing happens (Shortcuts.app surfaces its own error).
///
/// Per §4.4 brainstorm decision: Shortcuts URL beats AppleScript / Apple Events
/// for this use case (zero permission prompt, public API, matches Apple's
/// documented automation entry point).
@MainActor
final class FocusController {
    /// Invokes `shortcuts://run-shortcut?name=<url-encoded>`. Safe to call with
    /// nil — no-op.
    func run(shortcutName: String?) {
        guard let name = shortcutName, !name.isEmpty else { return }
        var components = URLComponents()
        components.scheme = "shortcuts"
        components.host = "run-shortcut"
        components.queryItems = [URLQueryItem(name: "name", value: name)]
        guard let url = components.url else { return }
        NSWorkspace.shared.open(url)
    }

    /// Convenience: run the `On` or `Off` shortcut from a FocusModeReference.
    func run(focusMode: FocusModeReference?, activating: Bool) {
        guard let focus = focusMode else { return }
        run(shortcutName: activating ? focus.shortcutNameOn : focus.shortcutNameOff)
    }
}
