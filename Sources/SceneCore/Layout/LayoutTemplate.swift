import CoreGraphics

public enum LayoutTemplate: String, Codable, CaseIterable, Sendable, Equatable {
    case single
    case twoCol, threeCol
    case twoRow, threeRow
    case grid2x2, grid3x2
    case lShapeLeft, lShapeRight, lShapeTop, lShapeBottom

    public static let proportionMinimum: Double = 0.05
    public static let proportionMaximum: Double = 0.95
    public static let proportionMinGap:  Double = 0.05

    public var slotCount: Int {
        switch self {
        case .single: return 1
        case .twoCol, .twoRow: return 2
        case .threeCol, .threeRow, .lShapeLeft, .lShapeRight, .lShapeTop, .lShapeBottom: return 3
        case .grid2x2: return 4
        case .grid3x2: return 6
        }
    }

    public var expectedProportionsCount: Int {
        switch self {
        case .single: return 0
        case .twoCol, .twoRow: return 1
        case .threeCol, .threeRow: return 2
        case .grid2x2: return 2
        case .grid3x2: return 3
        case .lShapeLeft, .lShapeRight, .lShapeTop, .lShapeBottom: return 2
        }
    }

    public var defaultProportions: [Double] {
        switch self {
        case .single: return []
        case .twoCol, .twoRow: return [0.5]
        case .threeCol, .threeRow: return [1.0/3.0, 2.0/3.0]
        case .grid2x2: return [0.5, 0.5]
        case .grid3x2: return [1.0/3.0, 2.0/3.0, 0.5]
        case .lShapeLeft, .lShapeRight, .lShapeTop, .lShapeBottom: return [0.5, 0.5]
        }
    }

    public func slots(proportions raw: [Double]) -> [Slot] {
        let p = sanitized(raw)
        switch self {
        case .single:
            return [Slot(rect: CGRect(x: 0, y: 0, width: 1, height: 1))]

        case .twoCol:
            let x = p[0]
            return [
                Slot(rect: CGRect(x: 0, y: 0, width: x,       height: 1)),
                Slot(rect: CGRect(x: x, y: 0, width: 1.0 - x, height: 1)),
            ]

        case .threeCol:
            let x1 = min(p[0], p[1]), x2 = max(p[0], p[1])
            return [
                Slot(rect: CGRect(x: 0,  y: 0, width: x1,       height: 1)),
                Slot(rect: CGRect(x: x1, y: 0, width: x2 - x1,  height: 1)),
                Slot(rect: CGRect(x: x2, y: 0, width: 1.0 - x2, height: 1)),
            ]

        case .twoRow:
            let y = p[0]
            return [
                Slot(rect: CGRect(x: 0, y: 0, width: 1, height: y)),
                Slot(rect: CGRect(x: 0, y: y, width: 1, height: 1.0 - y)),
            ]

        case .threeRow:
            let y1 = min(p[0], p[1]), y2 = max(p[0], p[1])
            return [
                Slot(rect: CGRect(x: 0, y: 0,  width: 1, height: y1)),
                Slot(rect: CGRect(x: 0, y: y1, width: 1, height: y2 - y1)),
                Slot(rect: CGRect(x: 0, y: y2, width: 1, height: 1.0 - y2)),
            ]

        case .grid2x2:
            let x = p[0], y = p[1]
            return [
                Slot(rect: CGRect(x: 0, y: 0, width: x,       height: y)),
                Slot(rect: CGRect(x: x, y: 0, width: 1.0 - x, height: y)),
                Slot(rect: CGRect(x: 0, y: y, width: x,       height: 1.0 - y)),
                Slot(rect: CGRect(x: x, y: y, width: 1.0 - x, height: 1.0 - y)),
            ]

        case .grid3x2:
            let x1 = min(p[0], p[1]), x2 = max(p[0], p[1]), y = p[2]
            return [
                Slot(rect: CGRect(x: 0,  y: 0, width: x1,       height: y)),
                Slot(rect: CGRect(x: x1, y: 0, width: x2 - x1,  height: y)),
                Slot(rect: CGRect(x: x2, y: 0, width: 1.0 - x2, height: y)),
                Slot(rect: CGRect(x: 0,  y: y, width: x1,       height: 1.0 - y)),
                Slot(rect: CGRect(x: x1, y: y, width: x2 - x1,  height: 1.0 - y)),
                Slot(rect: CGRect(x: x2, y: y, width: 1.0 - x2, height: 1.0 - y)),
            ]

        case .lShapeLeft:
            /// Big block on left. p[0] = main width fraction; p[1] = vertical split inside the right stack.
            /// Slot order: [main, top-stack, bottom-stack]. p[0] is always the main pane's primary dimension.
            let mainW = p[0], stackY = p[1]
            return [
                Slot(rect: CGRect(x: 0,     y: 0,      width: mainW,       height: 1)),
                Slot(rect: CGRect(x: mainW, y: 0,      width: 1.0 - mainW, height: stackY)),
                Slot(rect: CGRect(x: mainW, y: stackY, width: 1.0 - mainW, height: 1.0 - stackY)),
            ]

        case .lShapeRight:
            /// Big block on right. p[0] = main width fraction; p[1] = vertical split inside the left stack.
            /// Slot order: [top-stack, bottom-stack, main]. p[0] is always the main pane's primary dimension.
            let mainW = p[0], stackY = p[1]
            let leftW = 1.0 - mainW
            return [
                Slot(rect: CGRect(x: 0,     y: 0,      width: leftW, height: stackY)),
                Slot(rect: CGRect(x: 0,     y: stackY, width: leftW, height: 1.0 - stackY)),
                Slot(rect: CGRect(x: leftW, y: 0,      width: mainW, height: 1)),
            ]

        case .lShapeTop:
            /// Big block on top. p[0] = main height fraction; p[1] = horizontal split inside the bottom pair.
            /// Slot order: [main, bottom-left, bottom-right]. p[0] is always the main pane's primary dimension.
            let mainH = p[0], pairX = p[1]
            return [
                Slot(rect: CGRect(x: 0,     y: 0,     width: 1,           height: mainH)),
                Slot(rect: CGRect(x: 0,     y: mainH, width: pairX,       height: 1.0 - mainH)),
                Slot(rect: CGRect(x: pairX, y: mainH, width: 1.0 - pairX, height: 1.0 - mainH)),
            ]

        case .lShapeBottom:
            /// Big block on bottom. p[0] = main height fraction; p[1] = horizontal split inside the top pair.
            /// Slot order: [top-left, top-right, main]. p[0] is always the main pane's primary dimension.
            let mainH = p[0], pairX = p[1]
            let topH = 1.0 - mainH
            return [
                Slot(rect: CGRect(x: 0,     y: 0,    width: pairX,       height: topH)),
                Slot(rect: CGRect(x: pairX, y: 0,    width: 1.0 - pairX, height: topH)),
                Slot(rect: CGRect(x: 0,     y: topH, width: 1,           height: mainH)),
            ]
        }
    }

    private func sanitized(_ raw: [Double]) -> [Double] {
        let source = raw.count == expectedProportionsCount ? raw : defaultProportions
        let clamped = source.map { value -> Double in
            guard !value.isNaN else { return 0.5 }
            return min(max(value, Self.proportionMinimum), Self.proportionMaximum)
        }
        // For 3-way splits (threeCol/threeRow/grid3x2), enforce a minimum gap so the middle slot
        // never collapses to zero width/height even when both handles converge.
        switch self {
        case .threeCol, .threeRow:
            let sorted = clamped.sorted()
            let gap = max(Self.proportionMinGap, sorted[1] - sorted[0])
            let mid = (sorted[0] + sorted[1]) / 2
            return [
                min(max(mid - gap / 2, Self.proportionMinimum), Self.proportionMaximum - Self.proportionMinGap),
                min(max(mid + gap / 2, Self.proportionMinimum + Self.proportionMinGap), Self.proportionMaximum),
            ]
        case .grid3x2:
            // first two are column dividers (must respect min-gap); third is row divider (independent)
            let cols = Array(clamped.prefix(2)).sorted()
            let gap = max(Self.proportionMinGap, cols[1] - cols[0])
            let mid = (cols[0] + cols[1]) / 2
            return [
                min(max(mid - gap / 2, Self.proportionMinimum), Self.proportionMaximum - Self.proportionMinGap),
                min(max(mid + gap / 2, Self.proportionMinimum + Self.proportionMinGap), Self.proportionMaximum),
                clamped[2],
            ]
        default:
            return clamped
        }
    }
}
