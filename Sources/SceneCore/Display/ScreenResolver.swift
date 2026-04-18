import AppKit
import CoreGraphics

public enum ScreenResolver {
    public static func activeScreen() -> NSScreen {
        if let screen = screenContaining(point: NSEvent.mouseLocation) {
            return screen
        }
        return NSScreen.main ?? NSScreen.screens.first!
    }

    public static func screenContaining(point: CGPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(point) }
    }

    public static func screenForWindow(_ window: any WindowRef) -> NSScreen? {
        let center = CGPoint(x: window.frame.midX, y: window.frame.midY)
        return screenContaining(point: center)
    }
}
