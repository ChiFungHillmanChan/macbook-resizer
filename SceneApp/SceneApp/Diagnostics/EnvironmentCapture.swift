import AppKit
import SceneCore

/// Bridges AppKit's `NSScreen` to SceneCore's framework-neutral
/// `ScreenRecord` (integer fields, deterministic signature).
///
/// `@MainActor` because `NSScreen.main`, `NSScreen.screens`, and
/// `deviceDescription` are main-actor-isolated.
@MainActor
enum EnvironmentCapture {
    static func screenRecord(from screen: NSScreen) -> ScreenRecord {
        let id = displayID(of: screen)
        let frame = screen.frame
        let vf = screen.visibleFrame
        return ScreenRecord(
            id: id,
            x: Int((frame.origin.x).rounded()),
            y: Int((frame.origin.y).rounded()),
            w: Int((frame.size.width).rounded()),
            h: Int((frame.size.height).rounded()),
            vx: Int((vf.origin.x).rounded()),
            vy: Int((vf.origin.y).rounded()),
            vw: Int((vf.size.width).rounded()),
            vh: Int((vf.size.height).rounded()),
            scale100: Int((screen.backingScaleFactor * 100).rounded()),
            main: screen == NSScreen.main
        )
    }

    static func currentScreenRecords() -> [ScreenRecord] {
        NSScreen.screens.map(screenRecord(from:))
    }

    static func snapshot(
        activeScreen: NSScreen?,
        winCount: Int,
        activeWS: UUID?,
        secsSinceLastChange: TimeInterval? = nil
    ) -> EnvironmentSnapshot {
        let screens = currentScreenRecords()
        let activeID: UInt32 = activeScreen.map(displayID(of:)) ?? 0
        return EnvironmentSnapshot(
            ts: Date(),
            screens: screens,
            activeID: activeID,
            winCount: winCount,
            activeWS: activeWS,
            secsSinceLastChange: secsSinceLastChange
        )
    }

    static func displayID(of screen: NSScreen) -> UInt32 {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (screen.deviceDescription[key] as? NSNumber)?.uint32Value ?? 0
    }
}
