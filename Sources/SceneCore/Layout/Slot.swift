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

    public func absoluteRect(in visibleFrame: CGRect) -> CGRect {
        CGRect(
            x: visibleFrame.minX + rect.minX * visibleFrame.width,
            y: visibleFrame.minY + rect.minY * visibleFrame.height,
            width: rect.width * visibleFrame.width,
            height: rect.height * visibleFrame.height
        )
    }
}
