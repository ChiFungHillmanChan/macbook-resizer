import CoreGraphics

public struct Placement: Sendable, Equatable {
    public let windowID: CGWindowID
    public let targetFrame: CGRect

    public init(windowID: CGWindowID, targetFrame: CGRect) {
        self.windowID = windowID
        self.targetFrame = targetFrame
    }
}

public struct Plan: Sendable, Equatable {
    public let placements: [Placement]
    public let toMinimize: [CGWindowID]
    public let leftEmptySlotCount: Int

    public init(placements: [Placement], toMinimize: [CGWindowID], leftEmptySlotCount: Int) {
        self.placements = placements
        self.toMinimize = toMinimize
        self.leftEmptySlotCount = leftEmptySlotCount
    }

    public var isEmpty: Bool { placements.isEmpty && toMinimize.isEmpty }
}

public enum Outcome: Sendable, Equatable {
    case applied(placed: Int, minimized: Int, leftEmpty: Int, failed: Int)
    case noWindows
}
