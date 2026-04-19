import AppKit
import CoreGraphics
import SceneCore
import protocol SceneCore.WindowRef

// `SceneWindowRef` is already declared at module scope by `WindowAnimator.swift`
// to disambiguate from QuickDraw's `WindowRef` typedef. Reuse it here.

/// Bridges SceneCore's pure `WindowAnimationSink` protocol to the V0.2
/// `WindowAnimator`, reading the latest `SettingsStore.animation` config at
/// call time so drag-swap animations stay in sync with the Animation tab.
@MainActor
final class DragSwapAnimationSink: WindowAnimationSink {
    private let animator: WindowAnimator
    private let settingsStore: SettingsStore

    init(animator: WindowAnimator, settingsStore: SettingsStore) {
        self.animator = animator
        self.settingsStore = settingsStore
    }

    func animate(window: any SceneWindowRef, to target: CGRect) {
        let cfg = settingsStore.animation
        let placement = Placement(windowID: window.id, targetFrame: target)
        animator.animate(windows: [window], placements: [placement], config: cfg)
    }
}
