import ApplicationServices
import Foundation

public enum AXPermission {
    public static func check() -> Bool {
        AXIsProcessTrusted()
    }

    public static func requestWithPrompt() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    public static let systemSettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    )
}
