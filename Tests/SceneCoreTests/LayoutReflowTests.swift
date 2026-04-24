import XCTest
import CoreGraphics
@testable import SceneCore

final class LayoutReflowTests: XCTestCase {
    /// Standard visibleFrame used by most tests — 1000×800 at origin (0, 0).
    /// Keeps fraction ↔ pixel math trivial (1px = 0.001, 1000px = 1.0).
    let vf = CGRect(x: 0, y: 0, width: 1000, height: 800)

    // MARK: - twoCol

    func testTwoColSlot0RightEdgeShortened() {
        // Original halves: slot 0 rect = (0, 0, 500, 800). User drags right edge
        // to x=400 so slot 0 shrinks to 400 wide. Expect new proportion = 0.4.
        let result = LayoutReflow.reflow(
            template: .twoCol,
            proportions: [0.5],
            slotIdx: 0,
            newWindowFrame: CGRect(x: 0, y: 0, width: 400, height: 800),
            visibleFrame: vf
        )
        XCTAssertEqual(result, [0.4])
    }

    func testTwoColSlot0RightEdgeLengthened() {
        let result = LayoutReflow.reflow(
            template: .twoCol,
            proportions: [0.5],
            slotIdx: 0,
            newWindowFrame: CGRect(x: 0, y: 0, width: 700, height: 800),
            visibleFrame: vf
        )
        XCTAssertEqual(result, [0.7])
    }

    func testTwoColSlot1LeftEdgeShortened() {
        // Original halves: slot 1 rect = (500, 0, 500, 800). User drags left edge
        // leftward to x=400. Expect new proportion = 0.4.
        let result = LayoutReflow.reflow(
            template: .twoCol,
            proportions: [0.5],
            slotIdx: 1,
            newWindowFrame: CGRect(x: 400, y: 0, width: 600, height: 800),
            visibleFrame: vf
        )
        XCTAssertEqual(result, [0.4])
    }

    func testTwoColClampToLowerBound() {
        // User drags right edge all the way to x=50 (5% — below 10% floor).
        let result = LayoutReflow.reflow(
            template: .twoCol,
            proportions: [0.5],
            slotIdx: 0,
            newWindowFrame: CGRect(x: 0, y: 0, width: 50, height: 800),
            visibleFrame: vf
        )
        XCTAssertEqual(result, [0.1])
    }

    func testTwoColClampToUpperBound() {
        let result = LayoutReflow.reflow(
            template: .twoCol,
            proportions: [0.5],
            slotIdx: 0,
            newWindowFrame: CGRect(x: 0, y: 0, width: 950, height: 800),
            visibleFrame: vf
        )
        XCTAssertEqual(result, [0.9])
    }

    func testTwoColInvalidSlotIdx() {
        XCTAssertNil(LayoutReflow.reflow(
            template: .twoCol,
            proportions: [0.5],
            slotIdx: 2,
            newWindowFrame: CGRect(x: 0, y: 0, width: 500, height: 800),
            visibleFrame: vf
        ))
    }

    func testTwoColProportionsCountMismatch() {
        // Two proportions is wrong for twoCol — caller bug; return nil.
        XCTAssertNil(LayoutReflow.reflow(
            template: .twoCol,
            proportions: [0.5, 0.5],
            slotIdx: 0,
            newWindowFrame: CGRect(x: 0, y: 0, width: 400, height: 800),
            visibleFrame: vf
        ))
    }

    // MARK: - twoRow

    func testTwoRowSlot0BottomEdge() {
        // Slot 0 of twoRow at proportion 0.5: rect y=[0, 0.5] × height.
        // User drags max-y edge to 300 (in vf coords). Expect new proportion = 0.375.
        let result = LayoutReflow.reflow(
            template: .twoRow,
            proportions: [0.5],
            slotIdx: 0,
            newWindowFrame: CGRect(x: 0, y: 0, width: 1000, height: 300),
            visibleFrame: vf
        )
        XCTAssertEqual(result, [0.375])
    }

    func testTwoRowSlot1TopEdge() {
        let result = LayoutReflow.reflow(
            template: .twoRow,
            proportions: [0.5],
            slotIdx: 1,
            newWindowFrame: CGRect(x: 0, y: 300, width: 1000, height: 500),
            visibleFrame: vf
        )
        XCTAssertEqual(result, [0.375])
    }

    // MARK: - threeCol

    func testThreeColSlot0RightEdge() {
        let result = LayoutReflow.reflow(
            template: .threeCol,
            proportions: [1.0/3.0, 2.0/3.0],
            slotIdx: 0,
            newWindowFrame: CGRect(x: 0, y: 0, width: 250, height: 800),
            visibleFrame: vf
        )
        XCTAssertNotNil(result)
        XCTAssertEqual(result![0], 0.25, accuracy: 0.001)
        XCTAssertEqual(result![1], 2.0/3.0, accuracy: 0.001)
    }

    func testThreeColSlot2LeftEdge() {
        let result = LayoutReflow.reflow(
            template: .threeCol,
            proportions: [1.0/3.0, 2.0/3.0],
            slotIdx: 2,
            newWindowFrame: CGRect(x: 800, y: 0, width: 200, height: 800),
            visibleFrame: vf
        )
        XCTAssertNotNil(result)
        XCTAssertEqual(result![0], 1.0/3.0, accuracy: 0.001)
        XCTAssertEqual(result![1], 0.8, accuracy: 0.001)
    }

    func testThreeColMiddleSlotLeftSeamMoves() {
        // Middle slot originally at [333.33, 666.66]. User drags left edge
        // leftward to x=200. Right edge stays. Expect proportions[0] = 0.2.
        let result = LayoutReflow.reflow(
            template: .threeCol,
            proportions: [1.0/3.0, 2.0/3.0],
            slotIdx: 1,
            newWindowFrame: CGRect(x: 200, y: 0, width: 466.66, height: 800),
            visibleFrame: vf
        )
        XCTAssertNotNil(result)
        XCTAssertEqual(result![0], 0.2, accuracy: 0.001)
        XCTAssertEqual(result![1], 2.0/3.0, accuracy: 0.001)
    }

    func testThreeColMiddleSlotRightSeamMoves() {
        // Middle slot originally at [333.33, 666.66]. User drags right edge
        // rightward to x=800. Left edge stays. Expect proportions[1] = 0.8.
        let result = LayoutReflow.reflow(
            template: .threeCol,
            proportions: [1.0/3.0, 2.0/3.0],
            slotIdx: 1,
            newWindowFrame: CGRect(x: 333.33, y: 0, width: 800 - 333.33, height: 800),
            visibleFrame: vf
        )
        XCTAssertNotNil(result)
        XCTAssertEqual(result![0], 1.0/3.0, accuracy: 0.001)
        XCTAssertEqual(result![1], 0.8, accuracy: 0.001)
    }

    func testThreeColLeftSeamCannotCrossRightSeam() {
        // User drags slot 0 right edge all the way to x=900 (above p[1]=0.667).
        // Clamp to p[1] - minGap = 0.667 - 0.05 = 0.617.
        let result = LayoutReflow.reflow(
            template: .threeCol,
            proportions: [1.0/3.0, 2.0/3.0],
            slotIdx: 0,
            newWindowFrame: CGRect(x: 0, y: 0, width: 900, height: 800),
            visibleFrame: vf
        )
        XCTAssertNotNil(result)
        XCTAssertEqual(result![0], 2.0/3.0 - LayoutTemplate.proportionMinGap, accuracy: 0.001)
        XCTAssertEqual(result![1], 2.0/3.0, accuracy: 0.001)
    }

    // MARK: - threeRow

    func testThreeRowSlot0BottomEdge() {
        let result = LayoutReflow.reflow(
            template: .threeRow,
            proportions: [1.0/3.0, 2.0/3.0],
            slotIdx: 0,
            newWindowFrame: CGRect(x: 0, y: 0, width: 1000, height: 200),
            visibleFrame: vf
        )
        XCTAssertNotNil(result)
        XCTAssertEqual(result![0], 0.25, accuracy: 0.001)
        XCTAssertEqual(result![1], 2.0/3.0, accuracy: 0.001)
    }

    // MARK: - non-zero visibleFrame origin

    func testVisibleFrameWithOffsetOrigin() {
        // Second-display scenario: visibleFrame doesn't start at (0, 0).
        let vf2 = CGRect(x: 2000, y: 100, width: 1000, height: 800)
        let result = LayoutReflow.reflow(
            template: .twoCol,
            proportions: [0.5],
            slotIdx: 0,
            newWindowFrame: CGRect(x: 2000, y: 100, width: 400, height: 800),
            visibleFrame: vf2
        )
        XCTAssertEqual(result, [0.4])
    }

    // MARK: - unsupported templates

    func testSingleReturnsNil() {
        XCTAssertNil(LayoutReflow.reflow(
            template: .single,
            proportions: [],
            slotIdx: 0,
            newWindowFrame: CGRect(x: 0, y: 0, width: 500, height: 800),
            visibleFrame: vf
        ))
    }

    func testGrid2x2ReturnsNil() {
        XCTAssertNil(LayoutReflow.reflow(
            template: .grid2x2,
            proportions: [0.5, 0.5],
            slotIdx: 0,
            newWindowFrame: CGRect(x: 0, y: 0, width: 400, height: 400),
            visibleFrame: vf
        ))
    }

    func testLShapeLeftReturnsNil() {
        XCTAssertNil(LayoutReflow.reflow(
            template: .lShapeLeft,
            proportions: [0.5, 0.5],
            slotIdx: 0,
            newWindowFrame: CGRect(x: 0, y: 0, width: 400, height: 800),
            visibleFrame: vf
        ))
    }

    // MARK: - degenerate inputs

    func testZeroWidthVisibleFrameReturnsNil() {
        XCTAssertNil(LayoutReflow.reflow(
            template: .twoCol,
            proportions: [0.5],
            slotIdx: 0,
            newWindowFrame: CGRect(x: 0, y: 0, width: 100, height: 800),
            visibleFrame: CGRect(x: 0, y: 0, width: 0, height: 800)
        ))
    }
}
