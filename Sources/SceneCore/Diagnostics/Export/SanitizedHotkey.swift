import Foundation

/// A hotkey is already PII-free (just a key code + modifier set) but we
/// wrap it for consistency with the other sanitized DTOs and to keep the
/// on-disk export format independent of `HotkeyBinding`'s evolution.
public struct SanitizedHotkey: Codable, Sendable, Equatable {
    public let keyCode: UInt32
    public let modifiers: [String]   // sorted raw values: ["command","shift",...]

    public init(keyCode: UInt32, modifiers: [String]) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    public init(_ binding: HotkeyBinding) {
        self.keyCode = binding.keyCode
        self.modifiers = binding.modifiers.map { $0.rawValue }.sorted()
    }
}
