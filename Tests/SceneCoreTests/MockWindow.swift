import Foundation
import CoreGraphics
@testable import SceneCore

final class MockWindow: WindowRef {
    let id: CGWindowID
    let bundleID: String?
    private(set) var frame: CGRect
    var isMinimized: Bool
    var isFullscreen: Bool
    private(set) var setFrameCallCount = 0
    private(set) var minimizeCallCount = 0
    var shouldThrowOnSet: Bool = false

    init(
        id: CGWindowID,
        bundleID: String? = nil,
        frame: CGRect = .zero,
        isMinimized: Bool = false,
        isFullscreen: Bool = false
    ) {
        self.id = id
        self.bundleID = bundleID
        self.frame = frame
        self.isMinimized = isMinimized
        self.isFullscreen = isFullscreen
    }

    func setFrame(_ rect: CGRect) throws {
        setFrameCallCount += 1
        if shouldThrowOnSet { throw MockError.boom }
        frame = rect
    }

    func minimize() throws {
        minimizeCallCount += 1
        isMinimized = true
    }

    enum MockError: Error { case boom }
}
