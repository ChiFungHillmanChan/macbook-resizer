import Foundation
import Carbon.HIToolbox

public struct HotkeyBinding: Codable, Equatable, Sendable {
    public let keyCode: UInt32
    public let modifiers: Set<HotkeyModifier>

    public init(keyCode: UInt32, modifiers: Set<HotkeyModifier>) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// Carbon-flag bitmask suitable for `RegisterEventHotKey`.
    public var carbonModifiers: UInt32 {
        var mask: Int = 0
        if modifiers.contains(.command) { mask |= cmdKey }
        if modifiers.contains(.shift)   { mask |= shiftKey }
        if modifiers.contains(.option)  { mask |= optionKey }
        if modifiers.contains(.control) { mask |= controlKey }
        return UInt32(mask)
    }

    /// Two bindings conflict iff they have identical keyCode and identical modifier set.
    public func conflicts(with other: HotkeyBinding) -> Bool {
        keyCode == other.keyCode && modifiers == other.modifiers
    }

    /// Human-readable chord, e.g. "⌃⌥⇧⌘A" — modifiers are emitted in canonical
    /// macOS order (control, option, shift, command), then the key glyph.
    public var displayString: String {
        var s = ""
        if modifiers.contains(.control) { s += "\u{2303}" } // ⌃
        if modifiers.contains(.option)  { s += "\u{2325}" } // ⌥
        if modifiers.contains(.shift)   { s += "\u{21E7}" } // ⇧
        if modifiers.contains(.command) { s += "\u{2318}" } // ⌘
        s += KeyCodeNames.string(for: keyCode)
        return s
    }
}

public enum HotkeyModifier: String, Codable, Sendable, CaseIterable {
    case command, shift, option, control
}

/// Maps a small set of Carbon virtual key codes to printable strings used by
/// `HotkeyBinding.displayString`. Unknown codes fall back to "Key<code>".
public enum KeyCodeNames {
    public static func string(for keyCode: UInt32) -> String {
        switch Int(keyCode) {
        // Letters A–Z
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        // Digits 0–9
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        // Whitespace / control
        case kVK_Space:     return "Space"
        case kVK_Return:    return "Return"
        case kVK_Escape:    return "Esc"
        case kVK_Tab:       return "Tab"
        case kVK_Delete:    return "Delete"
        // Arrows
        case kVK_LeftArrow:  return "\u{2190}" // ←
        case kVK_RightArrow: return "\u{2192}" // →
        case kVK_UpArrow:    return "\u{2191}" // ↑
        case kVK_DownArrow:  return "\u{2193}" // ↓
        default:
            return "Key\(keyCode)"
        }
    }
}
