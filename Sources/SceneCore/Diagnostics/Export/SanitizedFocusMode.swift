import Foundation

public struct SanitizedFocusMode: Codable, Sendable, Equatable {
    public let onShortcutNameHash: String?
    public let offShortcutNameHash: String?

    public init(onShortcutNameHash: String?, offShortcutNameHash: String?) {
        self.onShortcutNameHash = onShortcutNameHash
        self.offShortcutNameHash = offShortcutNameHash
    }
}
