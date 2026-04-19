import CoreGraphics
import Foundation

/// Abstracts the V0.2 `WindowAnimator` so `DragSwapController` can animate
/// the displaced window (and the source on `cancelDrag`) without importing
/// AppKit into its swap logic — keeping `swift test` coverage intact.
///
/// SceneApp provides `DragSwapAnimationSink` wrapping `WindowAnimator.animate(...)`
/// with the current `SettingsStore.animation` config. Tests pass a recording mock.
@MainActor
public protocol WindowAnimationSink: AnyObject {
    /// Animate `window` to `target`. Implementations read duration / easing from
    /// the live `SettingsStore.animation`. If `animation.enabled == false`,
    /// implementations should still write the target frame (instant).
    func animate(window: any WindowRef, to target: CGRect)
}
