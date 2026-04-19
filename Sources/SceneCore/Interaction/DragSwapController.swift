import AppKit
import ApplicationServices
import Foundation
import os

public final class DragSwapController {
    public struct Context {
        public let layout: Layout
        public let screen: NSScreen
        public let windows: [any WindowRef]

        public init(layout: Layout, screen: NSScreen, windows: [any WindowRef]) {
            self.layout = layout
            self.screen = screen
            self.windows = windows
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

    @MainActor
    internal func simulateMouseUp() { finishDrag() }

    internal var _testActiveDrag: ActiveDragSnapshot? {
        guard let drag = activeDrag else { return nil }
        return ActiveDragSnapshot(windowID: drag.windowID, targetSlotIdx: drag.targetSlotIdx)
    }

    @MainActor
    public func handleWindowMoved(windowID: CGWindowID, currentFrame: CGRect) {
        let cfg = config()
        guard cfg.enabled else { return }
        guard let ctx = contextProvider() else { return }
        guard mouseButtonsProbe() & 0b1 != 0 else { return }

        let vf = visibleFrameOverride?(ctx.screen) ?? ctx.screen.visibleFrame
        let center = CGPoint(x: currentFrame.midX, y: currentFrame.midY)
        let targetIdx = nearestSlot(to: center, layout: ctx.layout, visibleFrame: vf)
        activeDrag = ActiveDrag(windowID: windowID, targetSlotIdx: targetIdx, ctx: ctx)
        preview.show(at: ctx.layout.slots[targetIdx].absoluteRect(in: vf))
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
        let sourceOriginalSlotIdx = slots.enumerated().first(where: { (_, slot) in
            rectsApproxEqual(slot.absoluteRect(in: vf), source.frame, tolerance: 5)
        })?.offset

        let other = drag.ctx.windows.first { w in
            w.id != source.id && rectsApproxEqual(w.frame, targetRect, tolerance: 5)
        }

        do {
            try source.setFrame(targetRect)
            if let other, let sourceOriginalSlotIdx {
                let otherRect = slots[sourceOriginalSlotIdx].absoluteRect(in: vf)
                try other.setFrame(otherRect)
            }
        } catch {
            log.error("swap failed: \(String(describing: error), privacy: .public)")
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

internal struct ActiveDragSnapshot: Equatable {
    let windowID: CGWindowID
    let targetSlotIdx: Int
}

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
