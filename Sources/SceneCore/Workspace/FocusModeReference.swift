import Foundation

/// References a pair of macOS Shortcuts by name. Scene invokes them via the
/// `shortcuts://run-shortcut?name=...` URL scheme when a Workspace is activated
/// (`shortcutNameOn`) and deactivated (`shortcutNameOff`, if provided).
///
/// The user creates these Shortcuts in Shortcuts.app — typically "Set Focus to
/// Do Not Disturb" for On and "Turn Off Focus" for Off — and enters the Shortcut
/// names into the Workspace editor. Scene does not create or modify Shortcuts.
public struct FocusModeReference: Codable, Equatable, Hashable, Sendable {
    public var shortcutNameOn: String?
    public var shortcutNameOff: String?

    public init(shortcutNameOn: String? = nil, shortcutNameOff: String? = nil) {
        self.shortcutNameOn = shortcutNameOn
        self.shortcutNameOff = shortcutNameOff
    }
}
