import AppKit
import ApplicationServices
import CoreGraphics

public enum AXWindowEnumerator {
    public enum EnumerationError: Error {
        case permissionDenied
        case cgWindowListFailed
    }

    public static func listVisibleWindows(on screen: NSScreen) throws -> [AXWindow] {
        guard AXPermission.check() else { throw EnumerationError.permissionDenied }

        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            throw EnumerationError.cgWindowListFailed
        }

        var results: [AXWindow] = []
        for info in list {
            guard
                let id = info[kCGWindowNumber as String] as? CGWindowID,
                let pid = info[kCGWindowOwnerPID as String] as? pid_t,
                let layer = info[kCGWindowLayer as String] as? Int,
                layer == 0,
                let boundsDict = info[kCGWindowBounds as String] as? [String: CGFloat],
                let cgBounds = boundsFromDict(boundsDict)
            else { continue }

            let centerTopLeft = CGPoint(x: cgBounds.midX, y: cgBounds.midY)
            guard screen.visibleFrame.contains(DisplayCoordinates.axToNS(centerTopLeft)) else { continue }

            let bundleID = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
            if let axWindow = buildAXWindow(pid: pid, id: id, bundleID: bundleID, bounds: cgBounds) {
                if !axWindow.isMinimized && !axWindow.isFullscreen {
                    results.append(axWindow)
                }
            }
        }
        return results
    }

    // MARK: - private

    private static func boundsFromDict(_ dict: [String: CGFloat]) -> CGRect? {
        guard
            let x = dict["X"], let y = dict["Y"],
            let w = dict["Width"], let h = dict["Height"]
        else { return nil }
        return CGRect(x: x, y: y, width: w, height: h)
    }

    private static func buildAXWindow(pid: pid_t, id: CGWindowID, bundleID: String?, bounds: CGRect) -> AXWindow? {
        let appElement = AXUIElementCreateApplication(pid)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement]
        else { return nil }

        for window in windows {
            var posRef: CFTypeRef?
            var sizeRef: CFTypeRef?
            AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posRef)
            AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef)
            guard let pos = posRef, let size = sizeRef else { continue }

            var point = CGPoint.zero
            var sz = CGSize.zero
            AXValueGetValue(pos as! AXValue, .cgPoint, &point)
            AXValueGetValue(size as! AXValue, .cgSize, &sz)
            let axFrame = CGRect(origin: point, size: sz)

            if rectsApproxEqual(axFrame, bounds, tolerance: 2) {
                return AXWindow(element: window, id: id, pid: pid, bundleID: bundleID)
            }
        }
        return nil
    }
}
