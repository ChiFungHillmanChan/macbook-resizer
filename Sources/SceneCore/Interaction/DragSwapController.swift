import AppKit
import ApplicationServices
import Foundation
import os

public final class DragSwapController {
    public struct Context {
        public let layout: Layout
        public let screen: NSScreen
        public let windows: [any WindowRef]
        /// Snapshot of which slot index each placed window occupied immediately after
        /// the most recent successful `applyLayout`. Used by `finishDrag` to recover
        /// the dragged window's original slot — `source.frame` reads AX live and by
        /// mouseUp time reflects the dragged position, not the original slot.
        public let windowToSlotIdx: [CGWindowID: Int]

        public init(
            layout: Layout,
            screen: NSScreen,
            windows: [any WindowRef],
            windowToSlotIdx: [CGWindowID: Int]
        ) {
            self.layout = layout
            self.screen = screen
            self.windows = windows
            self.windowToSlotIdx = windowToSlotIdx
        }
    }

    private let contextProvider: () -> Context?
    private let config: () -> DragSwapConfig
    private weak var animationSink: (any WindowAnimationSink)?
    private let modifierFlagsProbe: () -> NSEvent.ModifierFlags
    private let mouseButtonsProbe: () -> Int
    private let visibleFrameOverride: ((NSScreen) -> CGRect)?
    private let preview: DragPreviewOverlay
    private var mouseUpMonitor: Any?
    private var activeDrag: ActiveDrag?
    private var dragOrigin: DragOrigin?
    private let log = Logger(subsystem: "com.scene.core", category: "drag-swap")

    @MainActor
    public init(
        contextProvider: @escaping () -> Context?,
        config: @escaping () -> DragSwapConfig = { .default },
        animationSink: (any WindowAnimationSink)? = nil,
        modifierFlagsProbe: @escaping () -> NSEvent.ModifierFlags = { NSEvent.modifierFlags },
        mouseButtonsProbe: @escaping () -> Int = { NSEvent.pressedMouseButtons },
        visibleFrameOverride: ((NSScreen) -> CGRect)? = nil
    ) {
        self.contextProvider = contextProvider
        self.config = config
        self.animationSink = animationSink
        self.modifierFlagsProbe = modifierFlagsProbe
        self.mouseButtonsProbe = mouseButtonsProbe
        self.visibleFrameOverride = visibleFrameOverride
        self.preview = DragPreviewOverlay()
    }

    @MainActor
    public func start() {
        if mouseUpMonitor != nil { return }
        mouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] _ in
            Task { @MainActor in self?.finishDrag() }
        }
    }

    @MainActor
    public func stop() {
        if let monitor = mouseUpMonitor { NSEvent.removeMonitor(monitor) }
        mouseUpMonitor = nil
        preview.hide()
        activeDrag = nil
        dragOrigin = nil
    }

    deinit {
        // Release the global NSEvent monitor synchronously. `NSEvent.removeMonitor`
        // is nonisolated, so this is safe to call from a `@MainActor` class's deinit.
        if let monitor = mouseUpMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    @MainActor
    public func cancelDrag() {
        defer {
            preview.hide()
            activeDrag = nil
            dragOrigin = nil
        }
        guard let drag = activeDrag, let origin = dragOrigin, drag.windowID == origin.windowID else { return }
        guard let source = drag.ctx.windows.first(where: { $0.id == drag.windowID }) else { return }

        if let sink = animationSink {
            sink.animate(window: source, to: origin.frame)
        } else {
            do { try source.setFrame(origin.frame) }
            catch { log.error("cancel setFrame failed: \(String(describing: error), privacy: .public)") }
        }
    }

    #if DEBUG
    @MainActor
    internal func simulateMouseUp() { finishDrag() }

    internal var _testActiveDrag: ActiveDragSnapshot? {
        guard let drag = activeDrag else { return nil }
        return ActiveDragSnapshot(windowID: drag.windowID, targetSlotIdx: drag.targetSlotIdx)
    }
    #endif

    @MainActor
    public func handleWindowMoved(windowID: CGWindowID, currentFrame: CGRect) {
        let cfg = config()
        guard cfg.enabled else { return }
        guard !modifierFlagsProbe().contains(.option) else { return }
        // Self-fire guard: `WindowAnimator` writes AX frames during animation, which
        // fires `kAXMovedNotification` and re-enters this method. The mouse button
        // is never held during animator-driven writes, so this short-circuits cleanly
        // before any drag bookkeeping. (Spec lists this gate later in the order; we
        // run it earlier for cheaper short-circuiting.)
        guard mouseButtonsProbe() & 0b1 != 0 else { return }

        if dragOrigin?.windowID != windowID {
            dragOrigin = DragOrigin(windowID: windowID, frame: currentFrame)
        }
        guard let origin = dragOrigin else { return }

        let widthDelta = abs(currentFrame.width - origin.frame.width)
        let heightDelta = abs(currentFrame.height - origin.frame.height)
        if widthDelta > 5 || heightDelta > 5 {
            activeDrag = nil
            preview.hide()
            return
        }

        let dx = currentFrame.origin.x - origin.frame.origin.x
        let dy = currentFrame.origin.y - origin.frame.origin.y
        let dist = (dx * dx + dy * dy).squareRoot()
        guard dist >= cfg.distanceThresholdPt else { return }

        guard let ctx = contextProvider() else { return }
        guard ctx.windows.contains(where: { $0.id == windowID }) else { return }

        let vf = visibleFrameOverride?(ctx.screen) ?? ctx.screen.visibleFrame
        let center = CGPoint(x: currentFrame.midX, y: currentFrame.midY)
        let targetIdx = nearestSlot(to: center, layout: ctx.layout, visibleFrame: vf)
        let targetRect = ctx.layout.slots[targetIdx].absoluteRect(in: vf)

        guard targetRect.contains(center) else {
            activeDrag = nil
            preview.hide()
            return
        }

        activeDrag = ActiveDrag(windowID: windowID, targetSlotIdx: targetIdx, ctx: ctx)
        preview.show(at: targetRect)
    }

    @MainActor
    private func finishDrag() {
        defer {
            preview.hide()
            activeDrag = nil
            dragOrigin = nil
        }
        guard let drag = activeDrag else { return }
        let vf = visibleFrameOverride?(drag.ctx.screen) ?? drag.ctx.screen.visibleFrame
        let slots = drag.ctx.layout.slots
        guard let source = drag.ctx.windows.first(where: { $0.id == drag.windowID }) else { return }

        let targetRect = slots[drag.targetSlotIdx].absoluteRect(in: vf)

        // Look up source's original slot from the snapshot built at applyLayout time.
        // Don't infer from `source.frame` — `AXWindow.frame` reads AX live and at this
        // point reflects the dragged position (≈ targetRect), not the original slot.
        let sourceOriginalSlotIdx = drag.ctx.windowToSlotIdx[source.id]

        // Identify the displaced window by which placed window currently sits in the
        // target slot — also from the snapshot, not by frame matching (same reason).
        let otherID = drag.ctx.windowToSlotIdx
            .first(where: { $0.value == drag.targetSlotIdx && $0.key != source.id })?.key
        let other = otherID.flatMap { id in drag.ctx.windows.first(where: { $0.id == id }) }

        do { try source.setFrame(targetRect) }
        catch { log.error("swap source setFrame failed: \(String(describing: error), privacy: .public)") }

        if let other, let sourceOriginalSlotIdx {
            let otherRect = slots[sourceOriginalSlotIdx].absoluteRect(in: vf)
            if let sink = animationSink {
                sink.animate(window: other, to: otherRect)
            } else {
                do { try other.setFrame(otherRect) }
                catch { log.error("swap other setFrame failed: \(String(describing: error), privacy: .public)") }
            }
        }
    }
}

private struct ActiveDrag {
    let windowID: CGWindowID
    let targetSlotIdx: Int
    let ctx: DragSwapController.Context
}

private struct DragOrigin {
    let windowID: CGWindowID
    let frame: CGRect
}

#if DEBUG
internal struct ActiveDragSnapshot: Equatable {
    let windowID: CGWindowID
    let targetSlotIdx: Int
}
#endif

@MainActor
private final class DragPreviewOverlay {
    private var window: NSWindow?

    func show(at rect: CGRect) {
        if window == nil {
            let w = NSWindow(
                contentRect: rect,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            w.isOpaque = false
            w.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.25)
            w.level = .floating
            w.ignoresMouseEvents = true
            w.hasShadow = false
            window = w
        }
        window?.setFrame(rect, display: true, animate: false)
        window?.orderFront(nil)
    }

    func hide() {
        window?.orderOut(nil)
    }
}
