import XCTest
@testable import SceneCore

final class CustomLayoutTests: XCTestCase {
    func testCodableRoundTrip() throws {
        let original = CustomLayout(
            id: UUID(),
            name: "My Layout",
            template: .grid2x2,
            slotProportions: [0.4, 0.6],
            hotkey: HotkeyBinding(keyCode: 18, modifiers: [.command, .option]),
            isPresetSeed: false,
            isModified: true
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CustomLayout.self, from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.template, original.template)
        XCTAssertEqual(decoded.slotProportions, original.slotProportions)
        XCTAssertEqual(decoded.hotkey, original.hotkey)
        XCTAssertEqual(decoded.isPresetSeed, original.isPresetSeed)
        XCTAssertEqual(decoded.isModified, original.isModified)
    }

    func testToLayoutBuildsSlots() {
        let custom = CustomLayout(
            id: UUID(),
            name: "Halves",
            template: .twoCol,
            slotProportions: [0.5],
            hotkey: nil,
            isPresetSeed: true,
            isModified: false
        )
        let layout = custom.toLayout()
        XCTAssertEqual(layout.slots.count, 2)
        XCTAssertEqual(layout.slots[0].rect, CGRect(x: 0,   y: 0, width: 0.5, height: 1))
        XCTAssertEqual(layout.slots[1].rect, CGRect(x: 0.5, y: 0, width: 0.5, height: 1))
    }

    func testNoHotkeyEncodesAsNull() throws {
        let custom = CustomLayout(
            id: UUID(),
            name: "NoKey",
            template: .single,
            slotProportions: [],
            hotkey: nil,
            isPresetSeed: false,
            isModified: false
        )
        let data = try JSONEncoder().encode(custom)
        let json = String(data: data, encoding: .utf8) ?? ""
        // Either contains an explicit "hotkey":null or omits the field entirely.
        let containsNull   = json.contains("\"hotkey\":null")
        let omits          = !json.contains("\"hotkey\"")
        XCTAssertTrue(containsNull || omits, "expected hotkey to be encoded as null or omitted, got: \(json)")

        let decoded = try JSONDecoder().decode(CustomLayout.self, from: data)
        XCTAssertNil(decoded.hotkey)
    }
}
