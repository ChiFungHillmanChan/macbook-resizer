import CoreGraphics
import Foundation

/// Abstracts the AppKit / AX observer bridge so `DragSwapController` can be
/// unit-tested without spinning up real `AXObserver` instances.
///
/// SceneApp ships an `AXMoveObserverGroup` that conforms to this; tests use a
/// `MockWindowMoveObserver` that invokes the callback on demand.
public protocol WindowMoveObserving: AnyObject {
    /// Begin observing `kAXMovedNotification` for each window in `windowIDs`.
    /// The callback fires on the main thread with the window's current frame.
    /// Calling `startObserving` again replaces the prior set entirely.
    func startObserving(
        windowIDs: Set<CGWindowID>,
        onMove: @escaping (CGWindowID, CGRect) -> Void
    )

    /// Tear down all active observers. Idempotent.
    func stopObserving()
}
