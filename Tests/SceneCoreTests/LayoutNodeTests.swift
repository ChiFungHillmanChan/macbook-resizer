import XCTest
import CoreGraphics
@testable import SceneCore

final class LayoutNodeTests: XCTestCase {
    // MARK: - slotCount + depth

    func testSingleLeafCountAndDepth() {
        let tree = LayoutNode.leaf
        XCTAssertEqual(tree.slotCount, 1)
        XCTAssertEqual(tree.depth, 0)
    }

    func testSplitHSlotCount() {
        let tree = LayoutNode.splitH()
        XCTAssertEqual(tree.slotCount, 2)
        XCTAssertEqual(tree.depth, 1)
    }

    func testNestedSlotCount() {
        // vSplit -> left (hSplit leaf/leaf), right (leaf). 3 leaves.
        let tree: LayoutNode = .vSplit(
            ratio: 0.5,
            left: .splitH(),
            right: .leaf
        )
        XCTAssertEqual(tree.slotCount, 3)
        XCTAssertEqual(tree.depth, 2)
    }

    // MARK: - flatten correctness — single leaf

    func testFlattenLeafIsUnitSquare() {
        let slots = LayoutNode.leaf.flatten()
        XCTAssertEqual(slots.count, 1)
        XCTAssertEqual(slots[0].rect, CGRect(x: 0, y: 0, width: 1, height: 1))
    }

    // MARK: - flatten correctness — basic splits

    func testFlattenHSplitHalves() {
        // hSplit at 0.5: top = [0,0,1,0.5], bottom = [0,0.5,1,0.5]
        let slots = LayoutNode.splitH().flatten()
        XCTAssertEqual(slots.count, 2)
        XCTAssertEqual(slots[0].rect, CGRect(x: 0, y: 0,   width: 1, height: 0.5))
        XCTAssertEqual(slots[1].rect, CGRect(x: 0, y: 0.5, width: 1, height: 0.5))
    }

    func testFlattenVSplitHalves() {
        let slots = LayoutNode.splitV().flatten()
        XCTAssertEqual(slots.count, 2)
        XCTAssertEqual(slots[0].rect, CGRect(x: 0,   y: 0, width: 0.5, height: 1))
        XCTAssertEqual(slots[1].rect, CGRect(x: 0.5, y: 0, width: 0.5, height: 1))
    }

    func testFlattenHSplitAsymmetric() {
        let tree: LayoutNode = .hSplit(ratio: 0.3, top: .leaf, bottom: .leaf)
        let slots = tree.flatten()
        XCTAssertEqual(slots[0].rect, CGRect(x: 0, y: 0,   width: 1, height: 0.3))
        XCTAssertEqual(slots[1].rect, CGRect(x: 0, y: 0.3, width: 1, height: 0.7))
    }

    // MARK: - flatten correctness — the user's 5-slot example

    /// Reference tree for the user's "5-window desktop":
    ///
    /// vSplit 50%
    /// ├── left: hSplit 50%
    /// │          ├── top:    leaf (Slot 1: top-left big)
    /// │          └── bottom: vSplit 50%
    /// │                      ├── left:  leaf (Slot 2)
    /// │                      └── right: leaf (Slot 3)
    /// └── right: hSplit 50%
    ///            ├── top:    leaf (Slot 4: top-right big)
    ///            └── bottom: leaf (Slot 5: bottom-right big)
    func testFlattenUserFiveSlotExample() {
        let tree: LayoutNode = .vSplit(
            ratio: 0.5,
            left: .hSplit(
                ratio: 0.5,
                top: .leaf,
                bottom: .vSplit(ratio: 0.5, left: .leaf, right: .leaf)
            ),
            right: .hSplit(
                ratio: 0.5,
                top: .leaf,
                bottom: .leaf
            )
        )
        let slots = tree.flatten()
        XCTAssertEqual(slots.count, 5)

        // Depth-first order: left subtree first.
        // Slot 1: left column, top half. Rect = (0, 0, 0.5, 0.5).
        XCTAssertEqual(slots[0].rect, CGRect(x: 0, y: 0, width: 0.5, height: 0.5))
        // Slot 2: left column, bottom-left. Rect = (0, 0.5, 0.25, 0.5).
        XCTAssertEqual(slots[1].rect, CGRect(x: 0, y: 0.5, width: 0.25, height: 0.5))
        // Slot 3: left column, bottom-right. Rect = (0.25, 0.5, 0.25, 0.5).
        XCTAssertEqual(slots[2].rect, CGRect(x: 0.25, y: 0.5, width: 0.25, height: 0.5))
        // Slot 4: right column, top. Rect = (0.5, 0, 0.5, 0.5).
        XCTAssertEqual(slots[3].rect, CGRect(x: 0.5, y: 0, width: 0.5, height: 0.5))
        // Slot 5: right column, bottom. Rect = (0.5, 0.5, 0.5, 0.5).
        XCTAssertEqual(slots[4].rect, CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5))
    }

    // MARK: - 100% coverage invariant

    func testFlattenAlwaysTilesUnitSquareFullyAndExclusively() {
        // Exhaustive check on several trees: sum of slot areas = 1,
        // and no overlap (union of rects has 0 overlap).
        let trees: [LayoutNode] = [
            .leaf,
            .splitH(),
            .splitV(ratio: 0.3),
            .hSplit(ratio: 0.8, top: .splitV(ratio: 0.1), bottom: .splitV(ratio: 0.9)),
            .vSplit(ratio: 0.6,
                    left: .hSplit(ratio: 0.2, top: .leaf, bottom: .leaf),
                    right: .hSplit(ratio: 0.7, top: .leaf, bottom: .leaf))
        ]
        for tree in trees {
            let slots = tree.flatten()
            let area = slots.reduce(0.0) { $0 + Double($1.rect.width * $1.rect.height) }
            XCTAssertEqual(area, 1.0, accuracy: 1e-9,
                           "tree \(tree) did not tile the unit square")
            assertNoOverlap(slots: slots)
        }
    }

    private func assertNoOverlap(slots: [Slot], file: StaticString = #filePath, line: UInt = #line) {
        for i in 0..<slots.count {
            for j in (i + 1)..<slots.count {
                let inter = slots[i].rect.intersection(slots[j].rect)
                // Touching along an edge is allowed (zero area). Overlap is not.
                let interArea = Double(inter.width * inter.height)
                XCTAssertLessThan(interArea, 1e-9,
                                  "slots \(i) and \(j) overlap: \(slots[i].rect) ∩ \(slots[j].rect) = \(inter)",
                                  file: file, line: line)
            }
        }
    }

    // MARK: - clamp degenerate ratios

    func testFlattenClampsNegativeRatioToZero() {
        let tree: LayoutNode = .hSplit(ratio: -0.5, top: .leaf, bottom: .leaf)
        let slots = tree.flatten()
        XCTAssertEqual(slots[0].rect.height, 0, accuracy: 1e-9)
        XCTAssertEqual(slots[1].rect.height, 1, accuracy: 1e-9)
    }

    func testFlattenClampsOverOneRatioToOne() {
        let tree: LayoutNode = .vSplit(ratio: 1.5, left: .leaf, right: .leaf)
        let slots = tree.flatten()
        XCTAssertEqual(slots[0].rect.width, 1, accuracy: 1e-9)
        XCTAssertEqual(slots[1].rect.width, 0, accuracy: 1e-9)
    }

    func testFlattenNanRatioFallsBackToHalf() {
        let tree: LayoutNode = .hSplit(ratio: .nan, top: .leaf, bottom: .leaf)
        let slots = tree.flatten()
        XCTAssertEqual(slots[0].rect.height, 0.5, accuracy: 1e-9)
        XCTAssertEqual(slots[1].rect.height, 0.5, accuracy: 1e-9)
    }

    // MARK: - Codable round-trip

    func testCodableLeaf() throws {
        try roundTrip(.leaf)
    }

    func testCodableHSplit() throws {
        try roundTrip(.hSplit(ratio: 0.4, top: .leaf, bottom: .leaf))
    }

    func testCodableVSplit() throws {
        try roundTrip(.vSplit(ratio: 0.6, left: .leaf, right: .leaf))
    }

    func testCodableDeepNested() throws {
        let tree: LayoutNode = .vSplit(
            ratio: 0.5,
            left: .hSplit(
                ratio: 0.5,
                top: .leaf,
                bottom: .vSplit(ratio: 0.5, left: .leaf, right: .leaf)
            ),
            right: .hSplit(ratio: 0.5, top: .leaf, bottom: .leaf)
        )
        try roundTrip(tree)
    }

    func testCodableJSONIsStableShape() throws {
        // Lock in the on-disk JSON shape so we can be confident about
        // forward/backward compatibility. The canonical form uses `kind`
        // as the discriminator and `first` / `second` for children.
        let tree: LayoutNode = .hSplit(ratio: 0.5, top: .leaf, bottom: .leaf)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(tree)
        let json = String(data: data, encoding: .utf8) ?? ""
        XCTAssertEqual(
            json,
            #"{"first":{"kind":"leaf"},"kind":"hSplit","ratio":0.5,"second":{"kind":"leaf"}}"#
        )
    }

    private func roundTrip(_ tree: LayoutNode) throws {
        let data = try JSONEncoder().encode(tree)
        let decoded = try JSONDecoder().decode(LayoutNode.self, from: data)
        XCTAssertEqual(tree, decoded)
    }
}
