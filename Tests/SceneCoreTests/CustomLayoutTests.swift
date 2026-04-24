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

    // MARK: - V0.7 customTree

    func testToLayoutUsesCustomTreeWhenPresent() {
        // Tree overrides template + proportions. A leaf tree yields one full slot
        // even though `template` is `.grid2x2` and proportions are set.
        let custom = CustomLayout(
            id: UUID(),
            name: "Custom",
            template: .grid2x2,
            slotProportions: [0.5, 0.5],
            hotkey: nil,
            isPresetSeed: false,
            isModified: false,
            customTree: .leaf
        )
        let layout = custom.toLayout()
        XCTAssertEqual(layout.slots.count, 1)
        XCTAssertEqual(layout.slots[0].rect, CGRect(x: 0, y: 0, width: 1, height: 1))
    }

    func testToLayoutFallsBackToTemplateWhenNoTree() {
        let custom = CustomLayout(
            id: UUID(),
            name: "Template",
            template: .twoRow,
            slotProportions: [0.4],
            hotkey: nil,
            isPresetSeed: false,
            isModified: false
        )
        let layout = custom.toLayout()
        XCTAssertEqual(layout.slots.count, 2)
        XCTAssertEqual(layout.slots[0].rect.height, 0.4, accuracy: 1e-9)
    }

    func testCodableCustomTreeRoundTrip() throws {
        let tree: LayoutNode = .vSplit(
            ratio: 0.5,
            left: .hSplit(ratio: 0.5, top: .leaf, bottom: .vSplit(ratio: 0.5, left: .leaf, right: .leaf)),
            right: .hSplit(ratio: 0.5, top: .leaf, bottom: .leaf)
        )
        let original = CustomLayout(
            id: UUID(),
            name: "5-slot",
            template: .single, // placeholder — tree overrides
            slotProportions: [],
            hotkey: nil,
            isPresetSeed: false,
            isModified: false,
            customTree: tree
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CustomLayout.self, from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.customTree, tree)
        XCTAssertEqual(decoded.toLayout().slots.count, 5)
    }

    func testDecodeLegacyJSONWithoutCustomTreeKey() throws {
        // Old Scene.app (pre-V0.7) wrote `layouts.json` without a `customTree` key.
        // The new decoder MUST accept that JSON and set `customTree = nil`.
        let legacyJSON = #"""
        {
          "id": "11111111-0001-0000-0000-000000000001",
          "name": "Halves",
          "template": "twoCol",
          "slotProportions": [0.5],
          "hotkey": null,
          "isPresetSeed": true,
          "isModified": false
        }
        """#
        let data = legacyJSON.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(CustomLayout.self, from: data)
        XCTAssertNil(decoded.customTree)
        XCTAssertEqual(decoded.name, "Halves")
        XCTAssertEqual(decoded.template, .twoCol)
    }

    func testNoCustomTreeKeyOmittedFromEncoding() throws {
        // Template-only layouts should encode without a `customTree` key, so the
        // on-disk JSON stays minimal and older binaries can still read it (though
        // they'd reject a "customTree" field as unknown; actually JSONDecoder
        // ignores unknown keys by default, so this is more about file cleanliness).
        let custom = CustomLayout(
            id: UUID(),
            name: "Template-only",
            template: .twoCol,
            slotProportions: [0.5],
            hotkey: nil,
            isPresetSeed: false,
            isModified: false
        )
        let data = try JSONEncoder().encode(custom)
        let json = String(data: data, encoding: .utf8) ?? ""
        XCTAssertFalse(json.contains("customTree"),
                       "template-only layouts should not emit a customTree key, got: \(json)")
    }
}
