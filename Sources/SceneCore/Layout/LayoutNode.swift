import CoreGraphics
import Foundation

/// V0.7 "Custom layout build" — split-tree data model for user-authored layouts
/// that don't fit any of the fixed `LayoutTemplate` cases.
///
/// A `LayoutNode` is either a window slot (`.leaf`) or a binary split:
/// - `.hSplit(ratio, top, bottom)` — a horizontal seam. `ratio` is the TOP
///   child's share of the parent rect's height (in unit space).
/// - `.vSplit(ratio, left, right)` — a vertical seam. `ratio` is the LEFT
///   child's share of the parent rect's width (in unit space).
///
/// Coverage is 100% by construction: every leaf's rect is carved from its
/// parent's rect with no gaps and no overlaps, so the flattened slot list
/// always tiles the unit square.
///
/// The tree is a pure value type; the SwiftUI editor mutates it through
/// recursive `Binding<LayoutNode>` pairs rather than path-based helpers.
/// We expose `.splitH` / `.splitV` factory methods so the editor and tests
/// can build fresh subtrees without re-stating the `.leaf` children.
///
/// Codable uses an explicit `kind` discriminator so on-disk JSON is stable
/// and readable. Swift's default enum Codable would produce nested
/// `{ "hSplit": { "_0": 0.5, "_1": {...}, "_2": {...} } }` which is fragile
/// across Swift versions and awkward to inspect.
public indirect enum LayoutNode: Codable, Equatable, Sendable {
    case leaf
    case hSplit(ratio: Double, top: LayoutNode, bottom: LayoutNode)
    case vSplit(ratio: Double, left: LayoutNode, right: LayoutNode)

    // MARK: - Factory helpers

    /// Convenience: a horizontal split with two fresh leaf children at the
    /// given ratio (defaults to 50%).
    public static func splitH(ratio: Double = 0.5) -> LayoutNode {
        .hSplit(ratio: ratio, top: .leaf, bottom: .leaf)
    }

    /// Convenience: a vertical split with two fresh leaf children at the
    /// given ratio (defaults to 50%).
    public static func splitV(ratio: Double = 0.5) -> LayoutNode {
        .vSplit(ratio: ratio, left: .leaf, right: .leaf)
    }

    // MARK: - Queries

    /// Number of leaves reachable from this node (i.e., number of window
    /// slots the flattened layout will contain).
    public var slotCount: Int {
        switch self {
        case .leaf:                           return 1
        case .hSplit(_, let a, let b):        return a.slotCount + b.slotCount
        case .vSplit(_, let a, let b):        return a.slotCount + b.slotCount
        }
    }

    /// Depth of the tree (0 for a single leaf). Exposed for diagnostic /
    /// badge-count purposes; not used by the engine.
    public var depth: Int {
        switch self {
        case .leaf:                           return 0
        case .hSplit(_, let a, let b):        return 1 + max(a.depth, b.depth)
        case .vSplit(_, let a, let b):        return 1 + max(a.depth, b.depth)
        }
    }

    // MARK: - Flatten

    /// Flatten the tree into a `[Slot]` list in depth-first order
    /// (top-first for `.hSplit`, left-first for `.vSplit`). Slots are in unit
    /// coordinates — `LayoutEngine.plan` will materialize them via
    /// `Slot.absoluteRect(in: visibleFrame)` exactly as for template layouts.
    public func flatten() -> [Slot] {
        flatten(in: CGRect(x: 0, y: 0, width: 1, height: 1))
    }

    private func flatten(in rect: CGRect) -> [Slot] {
        switch self {
        case .leaf:
            return [Slot(rect: rect)]
        case .hSplit(let ratio, let top, let bottom):
            let r = Self.clampRatio(ratio)
            let topH = rect.height * CGFloat(r)
            let topRect = CGRect(
                x: rect.minX,
                y: rect.minY,
                width: rect.width,
                height: topH
            )
            let botRect = CGRect(
                x: rect.minX,
                y: rect.minY + topH,
                width: rect.width,
                height: rect.height - topH
            )
            return top.flatten(in: topRect) + bottom.flatten(in: botRect)
        case .vSplit(let ratio, let left, let right):
            let r = Self.clampRatio(ratio)
            let leftW = rect.width * CGFloat(r)
            let leftRect = CGRect(
                x: rect.minX,
                y: rect.minY,
                width: leftW,
                height: rect.height
            )
            let rightRect = CGRect(
                x: rect.minX + leftW,
                y: rect.minY,
                width: rect.width - leftW,
                height: rect.height
            )
            return left.flatten(in: leftRect) + right.flatten(in: rightRect)
        }
    }

    /// Per spec §V0.7-Q1 the user opted OUT of a minimum slot size floor —
    /// they want to author layouts on very large displays where a 2% slot
    /// is still usable. We still clamp to `[0, 1]` to guard against NaN /
    /// out-of-range values getting through from old JSON or bad math.
    private static func clampRatio(_ r: Double) -> Double {
        guard !r.isNaN else { return 0.5 }
        return min(max(r, 0.0), 1.0)
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case kind
        case ratio
        case first
        case second
    }

    private enum Kind: String, Codable {
        case leaf, hSplit, vSplit
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(Kind.self, forKey: .kind)
        switch kind {
        case .leaf:
            self = .leaf
        case .hSplit:
            let ratio = try c.decode(Double.self, forKey: .ratio)
            let top = try c.decode(LayoutNode.self, forKey: .first)
            let bottom = try c.decode(LayoutNode.self, forKey: .second)
            self = .hSplit(ratio: ratio, top: top, bottom: bottom)
        case .vSplit:
            let ratio = try c.decode(Double.self, forKey: .ratio)
            let left = try c.decode(LayoutNode.self, forKey: .first)
            let right = try c.decode(LayoutNode.self, forKey: .second)
            self = .vSplit(ratio: ratio, left: left, right: right)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .leaf:
            try c.encode(Kind.leaf, forKey: .kind)
        case .hSplit(let ratio, let top, let bottom):
            try c.encode(Kind.hSplit, forKey: .kind)
            try c.encode(ratio, forKey: .ratio)
            try c.encode(top, forKey: .first)
            try c.encode(bottom, forKey: .second)
        case .vSplit(let ratio, let left, let right):
            try c.encode(Kind.vSplit, forKey: .kind)
            try c.encode(ratio, forKey: .ratio)
            try c.encode(left, forKey: .first)
            try c.encode(right, forKey: .second)
        }
    }
}
