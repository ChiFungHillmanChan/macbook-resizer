import AppKit
import CoreGraphics

/// Converts rects between macOS's two coordinate systems:
///
/// - **NS coordinates** (`NSScreen.frame`, `NSScreen.visibleFrame`): bottom-left
///   origin, y increases upward, global across all displays anchored at the
///   primary display's bottom-left.
/// - **AX/CG coordinates** (`kAXPositionAttribute`, `CGWindowListCopyWindowInfo`,
///   `CGDisplayBounds`): top-left origin, y increases downward, anchored at the
///   primary display's top-left.
///
/// Scene computes layouts against `NSScreen.visibleFrame` but writes them via
/// AX, so every boundary crossing needs a vertical flip. On a single display,
/// or on the primary display specifically, `NS.visibleFrame.minY == 0` happens
/// to coincide with `AX.y == 0` for a full-height slot, which masks the bug.
/// On a secondary display with a non-zero NS offset, the flip is required —
/// otherwise windows land at the wrong y (commonly in the bottom half).
public enum DisplayCoordinates {
    /// Primary display height in points. By convention `NSScreen.screens[0]`
    /// is the primary display (origin `(0, 0)` in both NS and AX).
    /// Do NOT use `NSScreen.main` — that returns the screen with key focus,
    /// not the primary one, and will break the flip on any non-primary screen.
    public static func primaryHeight() -> CGFloat {
        NSScreen.screens.first?.frame.height ?? 0
    }

    /// Convert a rect from NSScreen (bottom-left) to AX/CG (top-left) coords.
    /// Pass `primaryHeight` explicitly so unit tests can pin the flip pivot
    /// without needing real displays.
    public static func nsToAX(_ rect: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(
            x: rect.origin.x,
            y: primaryHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }

    /// Convert a rect from AX/CG (top-left) to NSScreen (bottom-left) coords.
    /// The formula is its own inverse — flipping twice returns the original.
    public static func axToNS(_ rect: CGRect, primaryHeight: CGFloat) -> CGRect {
        nsToAX(rect, primaryHeight: primaryHeight)
    }

    /// Runtime convenience using the real primary screen height.
    public static func nsToAX(_ rect: CGRect) -> CGRect {
        nsToAX(rect, primaryHeight: primaryHeight())
    }

    public static func axToNS(_ rect: CGRect) -> CGRect {
        axToNS(rect, primaryHeight: primaryHeight())
    }

    /// Point variant — same flip formula, no height term.
    public static func axToNS(_ point: CGPoint, primaryHeight: CGFloat) -> CGPoint {
        CGPoint(x: point.x, y: primaryHeight - point.y)
    }

    public static func nsToAX(_ point: CGPoint, primaryHeight: CGFloat) -> CGPoint {
        axToNS(point, primaryHeight: primaryHeight)  // own inverse for points too
    }

    public static func axToNS(_ point: CGPoint) -> CGPoint {
        axToNS(point, primaryHeight: primaryHeight())
    }

    public static func nsToAX(_ point: CGPoint) -> CGPoint {
        nsToAX(point, primaryHeight: primaryHeight())
    }
}
