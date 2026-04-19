import AppKit
import ApplicationServices
import CoreGraphics
import os

enum AXWindowLookup {
    private static let log = Logger(subsystem: "com.scene.app", category: "ax-lookup")

    /// Resolve a `CGWindowID` to its `AXUIElement` via the same pattern
    /// `AXWindowEnumerator` uses: ask CGWindowList for the owner PID, create an
    /// AX application element, then iterate its windows matching position+size.
    ///
    /// Returns `nil` when the window disappeared, AX is disabled for the owner
    /// application, or the frame-match lookup fails. Callers should skip
    /// silently and log — one missing observer doesn't break the feature.
    static func element(for id: CGWindowID) -> AXUIElement? {
        let opts: CGWindowListOption = [.optionIncludingWindow]
        guard let list = CGWindowListCopyWindowInfo(opts, id) as? [[String: Any]],
              let info = list.first,
              let pid = info[kCGWindowOwnerPID as String] as? pid_t,
              let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
              let cgFrame = CGRect(dictionaryRepresentation: boundsDict as CFDictionary)
        else {
            log.debug("CGWindowList returned no info for id=\(id, privacy: .public)")
            return nil
        }

        let appElement = AXUIElementCreateApplication(pid)

        var windowsValue: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue)
        guard err == .success, let windows = windowsValue as? [AXUIElement] else {
            log.debug("AXUIElementCopyAttributeValue(.windows) failed for pid=\(pid, privacy: .public)")
            return nil
        }

        for window in windows {
            if let frame = axFrame(of: window), rectsApproxEqualLocal(frame, cgFrame, tolerance: 2) {
                return window
            }
        }
        return nil
    }

    static func axFrame(of element: AXUIElement) -> CGRect? {
        var posValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let p = posValue, let s = sizeValue
        else { return nil }

        // AXValue is the only sensible runtime type for kAXPosition / kAXSize, but
        // a non-conformant app could return something else. Use as? + guard to skip
        // silently per the spec's "log and continue" stance for AX failures.
        guard CFGetTypeID(p) == AXValueGetTypeID(),
              CFGetTypeID(s) == AXValueGetTypeID()
        else { return nil }
        var origin = CGPoint.zero
        var size = CGSize.zero
        let pAxValue = p as! AXValue
        let sAxValue = s as! AXValue
        AXValueGetValue(pAxValue, .cgPoint, &origin)
        AXValueGetValue(sAxValue, .cgSize, &size)
        return CGRect(origin: origin, size: size)
    }

    private static func rectsApproxEqualLocal(_ a: CGRect, _ b: CGRect, tolerance: CGFloat) -> Bool {
        abs(a.minX - b.minX) <= tolerance &&
        abs(a.minY - b.minY) <= tolerance &&
        abs(a.width - b.width) <= tolerance &&
        abs(a.height - b.height) <= tolerance
    }
}
