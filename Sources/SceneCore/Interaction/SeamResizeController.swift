import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import os

/// V0.6 "seam drag" feature.
///
/// While the user is holding left mouse and actively resizing one placed
/// window, infer which inner seam of the tiled layout is moving and reflow
/// the neighboring slot(s) so the surrounding windows resize in sympathy.
/// The user sees one window grow and the tile next to it shrink (or vice
/// versa) as if the whole layout were a single liquid grid.
///
/// Scope (see `LayoutReflow` for the full supported-template list):
/// - `.twoCol`, `.twoRow`, `.threeCol`, `.threeRow` — clear single-seam
///   reflows (or disambiguated two-seam reflow for a 3-way middle slot).
/// - All other templates (`.single`, grids, L-shapes): this controller
///   no-ops, letting the user resize freely without any reflow.
///
/// State model:
/// - `activeInitiatingID` holds the `CGWindowID` whose edge the user is
///   currently dragging. Subsequent AX events from other windows are
///   ignored until mouse-up; this is how we avoid re-entering on events
///   produced by our own `setFrame` writes to neighbor windows.
/// - The controller does NOT persist reflow — the on-disk `CustomLayout`
///   stays canonical. Re-firing the layout via hotkey snaps proportions
///   back to the saved values. Users who want to persist a new split edit
///   it in Settings → Layouts.
///
/// Mirrors `DragSwapController`'s injection pattern: all AppKit probes are
/// closures so tests can inject fakes without spinning up real `NSEvent`
/// monitors.
@MainActor
public final class SeamResizeController {
    /// All state the controller needs to reflow a single seam drag. Built
    /// by the composition root after each successful `applyLayout` — carries
    /// the template + proportions (unlike `DragSwapController.Context`,
    /// which only needs the derived `Layout.slots`) because reflow math
    /// operates on the template's proportion axes directly.
    public struct Context {
        public let template: LayoutTemplate
        public let proportions: [Double]
        public let screen: NSScreen
        public let windows: [any WindowRef]
        public let windowToSlotIdx: [CGWindowID: Int]

        public init(
            template: LayoutTemplate,
            proportions: [Double],
            screen: NSScreen,
            windows: [any WindowRef],
            windowToSlotIdx: [CGWindowID: Int]
        ) {
            self.template = template
            self.proportions = proportions
            self.screen = screen
            self.windows = windows
            self.windowToSlotIdx = windowToSlotIdx
        }
    }

    private let contextProvider: () -> Context?
    private let config: () -> DragSwapConfig
    private let modifierFlagsProbe: () -> NSEvent.ModifierFlags
    private let mouseButtonsProbe: () -> Int
    private let visibleFrameOverride: ((NSScreen) -> CGRect)?
    private let log = Logger(subsystem: "com.scene.core", category: "seam-resize")

    private var mouseUpMonitor: Any?
    private var activeInitiatingID: CGWindowID?

    @MainActor
    public init(
        contextProvider: @escaping () -> Context?,
        config: @escaping () -> DragSwapConfig = { .default },
        modifierFlagsProbe: @escaping () -> NSEvent.ModifierFlags = { NSEvent.modifierFlags },
        mouseButtonsProbe: @escaping () -> Int = { NSEvent.pressedMouseButtons },
        visibleFrameOverride: ((NSScreen) -> CGRect)? = nil
    ) {
        self.contextProvider = contextProvider
        self.config = config
        self.modifierFlagsProbe = modifierFlagsProbe
        self.mouseButtonsProbe = mouseButtonsProbe
        self.visibleFrameOverride = visibleFrameOverride
    }

    @MainActor
    public func start() {
        if mouseUpMonitor != nil { return }
        mouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] _ in
            Task { @MainActor in self?.activeInitiatingID = nil }
        }
    }

    @MainActor
    public func stop() {
        if let monitor = mouseUpMonitor { NSEvent.removeMonitor(monitor) }
        mouseUpMonitor = nil
        activeInitiatingID = nil
    }

    deinit {
        // `NSEvent.removeMonitor` is nonisolated — safe from a `@MainActor`
        // deinit (same reasoning as DragSwapController).
        if let monitor = mouseUpMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    /// Entry point called by the AX observer bridge whenever `kAXResizedNotification`
    /// fires for a tracked window. Idempotent with respect to mouse state — if the
    /// mouse isn't held (e.g. programmatic setFrame from an animator), short-circuits
    /// immediately without touching any other window.
    @MainActor
    public func handleWindowResized(windowID: CGWindowID, newFrame: CGRect) {
        let cfg = config()
        guard cfg.enabled else { return }
        guard !modifierFlagsProbe().contains(.option) else { return }
        // Self-fire guard: Scene's own `setFrame` writes to neighbor windows fire
        // `kAXResizedNotification` for those neighbors, re-entering this method.
        // The mouse button is never held during animator-driven or seam-reflow-driven
        // writes, so this short-circuits cleanly before any bookkeeping.
        guard mouseButtonsProbe() & 0b1 != 0 else { return }

        guard let ctx = contextProvider() else { return }
        guard let slotIdx = ctx.windowToSlotIdx[windowID] else { return }
        guard isSupportedTemplate(ctx.template) else { return }

        // Claim the initiating window on first resize event of this drag. Subsequent
        // events from other windows (including our own setFrame echoes, which are
        // additionally guarded above but belt-and-suspenders) are ignored.
        if activeInitiatingID == nil {
            activeInitiatingID = windowID
        }
        guard activeInitiatingID == windowID else { return }

        let vf = visibleFrameOverride?(ctx.screen) ?? ctx.screen.visibleFrame
        guard let newProportions = LayoutReflow.reflow(
            template: ctx.template,
            proportions: ctx.proportions,
            slotIdx: slotIdx,
            newWindowFrame: newFrame,
            visibleFrame: vf
        ) else { return }

        // Render the new slot rects and push them to all non-initiating windows.
        // The initiating window is excluded because the user is dragging it and
        // macOS already owns its frame; writing to it here would fight the drag.
        let newSlots = ctx.template.slots(proportions: newProportions)
        let slotToWindow = Dictionary(uniqueKeysWithValues: ctx.windowToSlotIdx.map { ($1, $0) })
        for (idx, slot) in newSlots.enumerated() where idx != slotIdx {
            guard let wid = slotToWindow[idx] else { continue }
            guard let window = ctx.windows.first(where: { $0.id == wid }) else { continue }
            let targetRect = slot.absoluteRect(in: vf)
            do {
                try window.setFrame(targetRect)
            } catch {
                log.error("seam reflow setFrame failed: \(String(describing: error), privacy: .public)")
            }
        }
    }

    #if DEBUG
    internal var _testActiveInitiatingID: CGWindowID? { activeInitiatingID }
    internal func _testSimulateMouseUp() { activeInitiatingID = nil }
    #endif

    private func isSupportedTemplate(_ t: LayoutTemplate) -> Bool {
        switch t {
        case .twoCol, .twoRow, .threeCol, .threeRow: return true
        case .single, .grid2x2, .grid3x2,
             .lShapeLeft, .lShapeRight, .lShapeTop, .lShapeBottom:
            return false
        }
    }
}
