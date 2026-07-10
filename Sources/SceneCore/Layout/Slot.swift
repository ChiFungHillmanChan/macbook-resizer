import CoreGraphics

public struct Slot: Sendable, Equatable {
    public let rect: CGRect

    public init(rect: CGRect) {
        self.rect = rect
    }

    public init?(safe rect: CGRect) {
        guard rect.minX >= 0, rect.minY >= 0,
              rect.maxX <= 1, rect.maxY <= 1,
              rect.width > 0, rect.height > 0 else { return nil }
        self.rect = rect
    }

    /// Materializes the unit rect into NS screen coordinates.
    ///
    /// Unit rects are authored in **top-left origin** space (y=0 = top of
    /// screen) — that's the convention of `LayoutTemplate.slots`,
    /// `LayoutNode.flatten`, and every SwiftUI renderer (thumbnails, editors).
    /// `visibleFrame` is NS **bottom-left origin** (y=0 = bottom), so the
    /// y-axis flips exactly once, here — mirroring how `AXWindow.setFrame`
    /// does the NS→AX flip exactly once at the AX write boundary.
    public func absoluteRect(in visibleFrame: CGRect) -> CGRect {
        CGRect(
            x: visibleFrame.minX + rect.minX * visibleFrame.width,
            y: visibleFrame.maxY - rect.maxY * visibleFrame.height,
            width: rect.width * visibleFrame.width,
            height: rect.height * visibleFrame.height
        )
    }
}
