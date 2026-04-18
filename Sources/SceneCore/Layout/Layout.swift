import CoreGraphics

public enum LayoutID: String, Sendable, CaseIterable, Codable {
    case full, halves, thirds, quads, mainSide, leftSplitRight, leftRightSplit
}

public struct Layout: Sendable, Identifiable {
    public let id: LayoutID
    public let name: String
    public let slots: [Slot]

    public static let full = Layout(
        id: .full,
        name: "Full",
        slots: [Slot(rect: CGRect(x: 0, y: 0, width: 1, height: 1))]
    )

    public static let halves = Layout(
        id: .halves,
        name: "Halves",
        slots: [
            Slot(rect: CGRect(x: 0,   y: 0, width: 0.5, height: 1)),
            Slot(rect: CGRect(x: 0.5, y: 0, width: 0.5, height: 1)),
        ]
    )

    public static let thirds = Layout(
        id: .thirds,
        name: "Thirds",
        slots: (0..<3).map { i in
            Slot(rect: CGRect(x: CGFloat(i)/3.0, y: 0, width: 1.0/3.0, height: 1))
        }
    )

    public static let quads = Layout(
        id: .quads,
        name: "Quads",
        slots: [
            Slot(rect: CGRect(x: 0,   y: 0,   width: 0.5, height: 0.5)),
            Slot(rect: CGRect(x: 0.5, y: 0,   width: 0.5, height: 0.5)),
            Slot(rect: CGRect(x: 0,   y: 0.5, width: 0.5, height: 0.5)),
            Slot(rect: CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5)),
        ]
    )

    public static let mainSide = Layout(
        id: .mainSide,
        name: "Main + Side",
        slots: [
            Slot(rect: CGRect(x: 0,   y: 0, width: 0.7, height: 1)),
            Slot(rect: CGRect(x: 0.7, y: 0, width: 0.3, height: 1)),
        ]
    )

    public static let leftSplitRight = Layout(
        id: .leftSplitRight,
        name: "LeftSplit + Right",
        slots: [
            Slot(rect: CGRect(x: 0,   y: 0,   width: 0.5, height: 0.5)),
            Slot(rect: CGRect(x: 0,   y: 0.5, width: 0.5, height: 0.5)),
            Slot(rect: CGRect(x: 0.5, y: 0,   width: 0.5, height: 1)),
        ]
    )

    public static let leftRightSplit = Layout(
        id: .leftRightSplit,
        name: "Left + RightSplit",
        slots: [
            Slot(rect: CGRect(x: 0,   y: 0,   width: 0.5, height: 1)),
            Slot(rect: CGRect(x: 0.5, y: 0,   width: 0.5, height: 0.5)),
            Slot(rect: CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5)),
        ]
    )

    public static let all: [Layout] = [full, halves, thirds, quads, mainSide, leftSplitRight, leftRightSplit]

    public static func layout(for id: LayoutID) -> Layout {
        all.first { $0.id == id }!
    }
}
