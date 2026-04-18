import CoreGraphics

public func rectsApproxEqual(_ a: CGRect, _ b: CGRect, tolerance: CGFloat) -> Bool {
    abs(a.minX   - b.minX)   <= tolerance &&
    abs(a.minY   - b.minY)   <= tolerance &&
    abs(a.width  - b.width)  <= tolerance &&
    abs(a.height - b.height) <= tolerance
}

public func nearestSlot(
    to point: CGPoint,
    layout: Layout,
    visibleFrame: CGRect
) -> Int {
    var bestIdx = 0
    var bestDist = CGFloat.infinity
    for (i, slot) in layout.slots.enumerated() {
        let rect = slot.absoluteRect(in: visibleFrame)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let dx = center.x - point.x
        let dy = center.y - point.y
        let dist = dx * dx + dy * dy
        if dist < bestDist {
            bestDist = dist
            bestIdx = i
        }
    }
    return bestIdx
}
