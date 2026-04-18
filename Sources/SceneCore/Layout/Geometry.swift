import CoreGraphics

public func rectsApproxEqual(_ a: CGRect, _ b: CGRect, tolerance: CGFloat) -> Bool {
    abs(a.minX   - b.minX)   <= tolerance &&
    abs(a.minY   - b.minY)   <= tolerance &&
    abs(a.width  - b.width)  <= tolerance &&
    abs(a.height - b.height) <= tolerance
}
