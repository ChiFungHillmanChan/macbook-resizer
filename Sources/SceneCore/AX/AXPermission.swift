import ApplicationServices
import Foundation

public enum AXPermission {
    /// Passive check via `AXIsProcessTrusted`. May return a stale `false` for the
    /// lifetime of the process if permission was granted while the app was running.
    public static func check() -> Bool {
        AXIsProcessTrusted()
    }

    /// Forces the system to refresh trust state without prompting. Use this in poll loops
    /// and explicit re-check buttons — `AXIsProcessTrusted()` alone often misses grants
    /// made while the app is running.
    public static func forceRecheck() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    public static func requestWithPrompt() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    public static let systemSettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    )
}
