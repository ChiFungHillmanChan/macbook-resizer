import CoreGraphics
import Foundation

/// Pure interpolation between two frames given a normalized progress `t ∈ [0, 1]`.
/// `t` outside that range clamps to the corresponding endpoint, and the endpoints
/// are returned exactly (no curve sampling) so animation runners can treat them as
/// terminal frames without floating-point drift.
public enum FrameInterpolator {
    public static func frame(
        start: CGRect,
        target: CGRect,
        easing: EasingCurve,
        t rawT: Double
    ) -> CGRect {
        let t = min(max(rawT, 0), 1)
        if t == 0 { return start }
        if t == 1 { return target }
        let p = curve(easing, t: t)
        return CGRect(
            x:      lerp(start.minX,   target.minX,   p),
            y:      lerp(start.minY,   target.minY,   p),
            width:  lerp(start.width,  target.width,  p),
            height: lerp(start.height, target.height, p)
        )
    }

    private static func lerp(_ a: CGFloat, _ b: CGFloat, _ p: Double) -> CGFloat {
        a + CGFloat(p) * (b - a)
    }

    private static func curve(_ easing: EasingCurve, t: Double) -> Double {
        switch easing {
        case .linear:  return t
        case .easeOut: return 1 - pow(1 - t, 3)
        case .spring:  return springProgress(t)
        }
    }

    /// Critically-damped-ish spring approximation. Monotonic-ish, fast settle.
    private static func springProgress(_ t: Double) -> Double {
        1 - exp(-6 * t) * cos(8 * t)
    }
}
