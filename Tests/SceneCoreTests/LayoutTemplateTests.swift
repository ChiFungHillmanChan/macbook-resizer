import XCTest
@testable import SceneCore

final class LayoutTemplateTests: XCTestCase {
    func testAllTemplatesPresent() {
        XCTAssertEqual(LayoutTemplate.allCases.count, 11)
    }

    func testProportionsCount() {
        XCTAssertEqual(LayoutTemplate.single.expectedProportionsCount, 0)
        XCTAssertEqual(LayoutTemplate.twoCol.expectedProportionsCount, 1)
        XCTAssertEqual(LayoutTemplate.twoRow.expectedProportionsCount, 1)
        XCTAssertEqual(LayoutTemplate.threeCol.expectedProportionsCount, 2)
        XCTAssertEqual(LayoutTemplate.threeRow.expectedProportionsCount, 2)
        XCTAssertEqual(LayoutTemplate.grid2x2.expectedProportionsCount, 2)
        XCTAssertEqual(LayoutTemplate.grid3x2.expectedProportionsCount, 3)
        XCTAssertEqual(LayoutTemplate.lShapeLeft.expectedProportionsCount, 2)
        XCTAssertEqual(LayoutTemplate.lShapeRight.expectedProportionsCount, 2)
        XCTAssertEqual(LayoutTemplate.lShapeTop.expectedProportionsCount, 2)
        XCTAssertEqual(LayoutTemplate.lShapeBottom.expectedProportionsCount, 2)
    }

    func testSlotCounts() {
        XCTAssertEqual(LayoutTemplate.single.slotCount, 1)
        XCTAssertEqual(LayoutTemplate.twoCol.slotCount, 2)
        XCTAssertEqual(LayoutTemplate.twoRow.slotCount, 2)
        XCTAssertEqual(LayoutTemplate.threeCol.slotCount, 3)
        XCTAssertEqual(LayoutTemplate.threeRow.slotCount, 3)
        XCTAssertEqual(LayoutTemplate.grid2x2.slotCount, 4)
        XCTAssertEqual(LayoutTemplate.grid3x2.slotCount, 6)
        XCTAssertEqual(LayoutTemplate.lShapeLeft.slotCount, 3)
        XCTAssertEqual(LayoutTemplate.lShapeRight.slotCount, 3)
        XCTAssertEqual(LayoutTemplate.lShapeTop.slotCount, 3)
        XCTAssertEqual(LayoutTemplate.lShapeBottom.slotCount, 3)
    }

    func testTwoColSplit() {
        let slots = LayoutTemplate.twoCol.slots(proportions: [0.7])
        XCTAssertEqual(slots.count, 2)
        assertRectEqual(slots[0].rect, CGRect(x: 0,   y: 0, width: 0.7, height: 1))
        assertRectEqual(slots[1].rect, CGRect(x: 0.7, y: 0, width: 0.3, height: 1))
    }

    func testThreeColSplit() {
        let slots = LayoutTemplate.threeCol.slots(proportions: [0.25, 0.6])
        XCTAssertEqual(slots.count, 3)
        assertRectEqual(slots[0].rect, CGRect(x: 0,    y: 0, width: 0.25, height: 1))
        assertRectEqual(slots[1].rect, CGRect(x: 0.25, y: 0, width: 0.35, height: 1))
        assertRectEqual(slots[2].rect, CGRect(x: 0.6,  y: 0, width: 0.4,  height: 1))
    }

    func testGrid2x2Split() {
        let slots = LayoutTemplate.grid2x2.slots(proportions: [0.5, 0.5])
        XCTAssertEqual(slots.count, 4)
        assertRectEqual(slots[0].rect, CGRect(x: 0,   y: 0,   width: 0.5, height: 0.5))
        assertRectEqual(slots[1].rect, CGRect(x: 0.5, y: 0,   width: 0.5, height: 0.5))
        assertRectEqual(slots[2].rect, CGRect(x: 0,   y: 0.5, width: 0.5, height: 0.5))
        assertRectEqual(slots[3].rect, CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5))
    }

    func testGrid3x2Split() {
        let slots = LayoutTemplate.grid3x2.slots(proportions: [1.0/3.0, 2.0/3.0, 0.5])
        XCTAssertEqual(slots.count, 6)
        XCTAssertEqual(Double(slots[0].rect.minX), 0,   accuracy: 1e-9)
        XCTAssertEqual(Double(slots[2].rect.maxX), 1,   accuracy: 1e-9)
        XCTAssertEqual(Double(slots[3].rect.minY), 0.5, accuracy: 1e-9)
    }

    func testLShapeLeftSlots() {
        let slots = LayoutTemplate.lShapeLeft.slots(proportions: [0.6, 0.5])
        XCTAssertEqual(slots.count, 3)
        assertRectEqual(slots[0].rect, CGRect(x: 0,   y: 0,   width: 0.6, height: 1))
        assertRectEqual(slots[1].rect, CGRect(x: 0.6, y: 0,   width: 0.4, height: 0.5))
        assertRectEqual(slots[2].rect, CGRect(x: 0.6, y: 0.5, width: 0.4, height: 0.5))
    }

    func testLShapeRightSlots() {
        let slots = LayoutTemplate.lShapeRight.slots(proportions: [0.6, 0.5])
        XCTAssertEqual(slots.count, 3)
        assertRectEqual(slots[0].rect, CGRect(x: 0,   y: 0,   width: 0.4, height: 0.5))
        assertRectEqual(slots[1].rect, CGRect(x: 0,   y: 0.5, width: 0.4, height: 0.5))
        assertRectEqual(slots[2].rect, CGRect(x: 0.4, y: 0,   width: 0.6, height: 1))
    }

    func testLShapeTopSlots() {
        let slots = LayoutTemplate.lShapeTop.slots(proportions: [0.6, 0.5])
        XCTAssertEqual(slots.count, 3)
        assertRectEqual(slots[0].rect, CGRect(x: 0,   y: 0,   width: 1,   height: 0.6))
        assertRectEqual(slots[1].rect, CGRect(x: 0,   y: 0.6, width: 0.5, height: 0.4))
        assertRectEqual(slots[2].rect, CGRect(x: 0.5, y: 0.6, width: 0.5, height: 0.4))
    }

    func testLShapeBottomSlots() {
        let slots = LayoutTemplate.lShapeBottom.slots(proportions: [0.6, 0.5])
        XCTAssertEqual(slots.count, 3)
        assertRectEqual(slots[0].rect, CGRect(x: 0,   y: 0,   width: 0.5, height: 0.4))
        assertRectEqual(slots[1].rect, CGRect(x: 0.5, y: 0,   width: 0.5, height: 0.4))
        assertRectEqual(slots[2].rect, CGRect(x: 0,   y: 0.4, width: 1,   height: 0.6))
    }

    func testDefaultProportionsValid() {
        for template in LayoutTemplate.allCases {
            XCTAssertEqual(
                template.defaultProportions.count,
                template.expectedProportionsCount,
                "defaultProportions count mismatch for \(template)"
            )
            let slots = template.slots(proportions: template.defaultProportions)
            XCTAssertEqual(slots.count, template.slotCount, "slot count mismatch for \(template)")
        }
    }

    func testCodableRoundTrip() throws {
        let original = LayoutTemplate.lShapeRight
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LayoutTemplate.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testNaNFallsBackToHalf() {
        let slots = LayoutTemplate.twoCol.slots(proportions: [.nan])
        XCTAssertEqual(slots[0].rect.width, 0.5, accuracy: 1e-9)
    }

    func testInfinityClampsToMaximum() {
        let slots = LayoutTemplate.twoCol.slots(proportions: [.infinity])
        XCTAssertEqual(slots[0].rect.width, LayoutTemplate.proportionMaximum, accuracy: 1e-9)
    }

    func testThreeColCollapsedHandlesPreserveMinGap() {
        let slots = LayoutTemplate.threeCol.slots(proportions: [0.5, 0.5])
        // Middle slot must be at least proportionMinGap wide
        XCTAssertGreaterThanOrEqual(slots[1].rect.width, LayoutTemplate.proportionMinGap - 1e-9)
    }

    func testWrongProportionsCountFallsBackToDefaults() {
        let slots = LayoutTemplate.twoCol.slots(proportions: [0.3, 0.7, 0.5])
        // Should use defaultProportions [0.5] → [(0,0,0.5,1), (0.5,0,0.5,1)]
        XCTAssertEqual(slots.count, 2)
        XCTAssertEqual(slots[0].rect.width, 0.5, accuracy: 1e-9)
    }

    // MARK: - helpers

    private func assertRectEqual(
        _ lhs: CGRect, _ rhs: CGRect,
        accuracy: Double = 1e-9, file: StaticString = #file, line: UInt = #line
    ) {
        XCTAssertEqual(Double(lhs.minX),   Double(rhs.minX),   accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(Double(lhs.minY),   Double(rhs.minY),   accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(Double(lhs.width),  Double(rhs.width),  accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(Double(lhs.height), Double(rhs.height), accuracy: accuracy, file: file, line: line)
    }
}
