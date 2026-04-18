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
    private let preview: DragPreviewOverlay
    private var mouseUpMonitor: Any?
    private var activeDrag: ActiveDrag?
    private let log = Logger(subsystem: "com.scene.core", category: "drag-swap")

    @MainActor
    public init(contextProvider: @escaping () -> Context?) {
        self.contextProvider = contextProvider
        self.preview = DragPreviewOverlay()
    }

    @MainActor
    public func start() {
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
    }

    @MainActor
    public func handleWindowMoved(windowID: CGWindowID, currentFrame: CGRect) {
        guard let ctx = contextProvider() else { return }
        guard NSEvent.pressedMouseButtons & 0b1 != 0 else { return }
        let center = CGPoint(x: currentFrame.midX, y: currentFrame.midY)
        let targetIdx = nearestSlot(to: center, layout: ctx.layout, visibleFrame: ctx.screen.visibleFrame)
        activeDrag = ActiveDrag(windowID: windowID, targetSlotIdx: targetIdx, ctx: ctx)
        preview.show(at: ctx.layout.slots[targetIdx].absoluteRect(in: ctx.screen.visibleFrame))
    }

    @MainActor
    private func finishDrag() {
        defer {
            preview.hide()
            activeDrag = nil
        }
        guard let drag = activeDrag else { return }
        let slots = drag.ctx.layout.slots
        let vf = drag.ctx.screen.visibleFrame
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
