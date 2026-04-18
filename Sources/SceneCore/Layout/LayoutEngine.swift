import CoreGraphics
import os

public enum LayoutEngine {
    public static func plan(
        windows: [any WindowRef],
        visibleFrame: CGRect,
        layout: Layout
    ) -> Plan {
        let slotCount = layout.slots.count
        let placedCount = min(windows.count, slotCount)
        let placements: [Placement] = (0..<placedCount).map { i in
            Placement(
                windowID: windows[i].id,
                targetFrame: layout.slots[i].absoluteRect(in: visibleFrame)
            )
        }
        let toMinimize: [CGWindowID] = windows.count > slotCount
            ? windows[slotCount...].map(\.id)
            : []
        let leftEmpty = max(0, slotCount - windows.count)
        return Plan(placements: placements, toMinimize: toMinimize, leftEmptySlotCount: leftEmpty)
    }
}

private let layoutEngineLog = Logger(subsystem: "com.scene.core", category: "layout-engine")

extension LayoutEngine {
    public static func apply(
        _ plan: Plan,
        on windows: [any WindowRef],
        electronTolerancePx: CGFloat = 5
    ) throws -> Outcome {
        if plan.isEmpty { return .noWindows }

        var byID: [CGWindowID: any WindowRef] = [:]
        for w in windows { byID[w.id] = w }

        var placed = 0
        var failed = 0

        for p in plan.placements {
            guard let window = byID[p.windowID] else {
                failed += 1
                continue
            }
            do {
                try window.setFrame(p.targetFrame)
                if !rectsApproxEqual(window.frame, p.targetFrame, tolerance: electronTolerancePx) {
                    let dx = p.targetFrame.origin.x - window.frame.origin.x
                    let dy = p.targetFrame.origin.y - window.frame.origin.y
                    let dw = p.targetFrame.width - window.frame.width
                    let dh = p.targetFrame.height - window.frame.height
                    let corrected = CGRect(
                        x: p.targetFrame.origin.x + dx,
                        y: p.targetFrame.origin.y + dy,
                        width: p.targetFrame.width + dw,
                        height: p.targetFrame.height + dh
                    )
                    try window.setFrame(corrected)
                }
                placed += 1
            } catch {
                layoutEngineLog.error("setFrame failed for \(window.bundleID ?? "unknown", privacy: .public): \(String(describing: error), privacy: .public)")
                failed += 1
            }
        }

        var minimized = 0
        for wid in plan.toMinimize {
            guard let window = byID[wid] else { continue }
            do {
                try window.minimize()
                minimized += 1
            } catch {
                layoutEngineLog.error("minimize failed for \(wid): \(String(describing: error), privacy: .public)")
                failed += 1
            }
        }

        return .applied(
            placed: placed,
            minimized: minimized,
            leftEmpty: plan.leftEmptySlotCount,
            failed: failed
        )
    }
}
