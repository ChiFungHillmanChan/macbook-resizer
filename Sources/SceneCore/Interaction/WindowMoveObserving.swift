import CoreGraphics
import Foundation

/// Abstracts the AppKit / AX observer bridge so `DragSwapController` and
/// `SeamResizeController` (V0.6) can be unit-tested without spinning up real
/// `AXObserver` instances.
///
/// SceneApp ships an `AXMoveObserverGroup` that conforms to this; tests use a
/// mock that invokes the callbacks on demand.
public protocol WindowMoveObserving: AnyObject {
    /// Begin observing `kAXMovedNotification` and `kAXResizedNotification` for
    /// each window in `windowIDs`. The callbacks fire on the main thread with
    /// the window's current frame. Calling `startObserving` again replaces the
    /// prior set entirely.
    ///
    /// `onMove` fires when the window's origin changed (drag-swap).
    /// `onResize` fires when the window's size changed (seam drag — V0.6).
    /// Both callbacks may fire in sequence for a single AX event when both the
    /// position and size of the window changed at once, as macOS occasionally
    /// coalesces them.
    func startObserving(
        windowIDs: Set<CGWindowID>,
        onMove: @escaping (CGWindowID, CGRect) -> Void,
        onResize: @escaping (CGWindowID, CGRect) -> Void
    )

    /// Tear down all active observers. Idempotent.
    func stopObserving()
}
