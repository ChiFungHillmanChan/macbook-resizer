import CoreGraphics

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
