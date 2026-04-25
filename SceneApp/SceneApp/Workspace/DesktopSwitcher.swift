import Carbon.HIToolbox
import CoreGraphics
import Foundation

@MainActor
protocol DesktopSwitching {
    func switchToDesktop(_ number: Int) async -> Bool
}

@MainActor
final class DesktopSwitcher: DesktopSwitching {
    private let settleDelay: Duration

    init(settleDelay: Duration = .milliseconds(250)) {
        self.settleDelay = settleDelay
    }

    func switchToDesktop(_ number: Int) async -> Bool {
        guard let keyCode = Self.keyCode(for: number),
              let source = CGEventSource(stateID: .hidSystemState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else { return false }

        down.flags = .maskControl
        up.flags = .maskControl
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        try? await Task.sleep(for: settleDelay)
        return true
    }

    private static func keyCode(for number: Int) -> CGKeyCode? {
        switch number {
        case 1: return CGKeyCode(kVK_ANSI_1)
        case 2: return CGKeyCode(kVK_ANSI_2)
        case 3: return CGKeyCode(kVK_ANSI_3)
        case 4: return CGKeyCode(kVK_ANSI_4)
        case 5: return CGKeyCode(kVK_ANSI_5)
        case 6: return CGKeyCode(kVK_ANSI_6)
        case 7: return CGKeyCode(kVK_ANSI_7)
        case 8: return CGKeyCode(kVK_ANSI_8)
        case 9: return CGKeyCode(kVK_ANSI_9)
        default: return nil
        }
    }
}
