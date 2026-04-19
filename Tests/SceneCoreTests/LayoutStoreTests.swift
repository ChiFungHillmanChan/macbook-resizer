import XCTest
import Carbon.HIToolbox
@testable import SceneCore

final class LayoutStoreTests: XCTestCase {
    private var fileURL: URL!

    override func setUpWithError() throws {
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("scene-tests-\(UUID().uuidString).json")
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    // MARK: - Seeding & persistence

    func testFirstLaunchSeedsSevenPresets() throws {
        let store = try LayoutStore(fileURL: fileURL)
        XCTAssertEqual(store.layouts.count, PresetSeeds.all.count)
        let names = Set(store.layouts.map(\.name))
        XCTAssertEqual(names, Set(["Full", "Halves", "Thirds", "Quads",
                                   "Main + Side", "LeftSplit + Right",
                                   "Left + RightSplit",
                                   "Main + Side (Vertical)", "Halves (Vertical)",
                                   "Thirds (Vertical)"]))
    }

    func testFirstLaunchPersistsAndKnownSeedUUIDs() throws {
        _ = try LayoutStore(fileURL: fileURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        let data = try Data(contentsOf: fileURL)
        let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(decoded?["version"] as? Int, 1)
        let known = decoded?["knownSeedUUIDs"] as? [String]
        XCTAssertEqual(known?.count, PresetSeeds.all.count)
    }

    func testSecondLaunchDoesNotReSeed() throws {
        let store1 = try LayoutStore(fileURL: fileURL)
        try store1.delete(id: PresetSeeds.fullID)
        XCTAssertEqual(store1.layouts.count, PresetSeeds.all.count - 1)

        let store2 = try LayoutStore(fileURL: fileURL)
        XCTAssertEqual(store2.layouts.count, PresetSeeds.all.count - 1)
        XCTAssertNil(store2.layouts.first(where: { $0.id == PresetSeeds.fullID }))
    }

    // MARK: - CRUD

    func testInsertAndUpdate() throws {
        let store = try LayoutStore(fileURL: fileURL)
        let id = UUID()
        let custom = CustomLayout(
            id: id, name: "Mine", template: .single, slotProportions: [],
            hotkey: nil, isPresetSeed: false, isModified: false
        )
        try store.insert(custom)
        XCTAssertEqual(store.layouts.count, PresetSeeds.all.count + 1)

        var renamed = custom
        renamed.name = "Renamed"
        try store.update(renamed)
        XCTAssertEqual(store.layouts.first(where: { $0.id == id })?.name, "Renamed")
    }

    func testEditSeedSetsIsModified() throws {
        let store = try LayoutStore(fileURL: fileURL)
        var halves = store.layouts.first(where: { $0.id == PresetSeeds.halvesID })!
        XCTAssertFalse(halves.isModified)
        halves.slotProportions = [0.6]
        try store.update(halves)

        let reloaded = try LayoutStore(fileURL: fileURL)
        let h = reloaded.layouts.first(where: { $0.id == PresetSeeds.halvesID })!
        XCTAssertTrue(h.isModified)
        XCTAssertTrue(h.isPresetSeed)
        XCTAssertEqual(h.slotProportions, [0.6])
    }

    // MARK: - Restore + future seeds

    func testRestoreDefaultPresetsReinserts() throws {
        let store = try LayoutStore(fileURL: fileURL)
        try store.delete(id: PresetSeeds.fullID)
        try store.delete(id: PresetSeeds.halvesID)
        XCTAssertEqual(store.layouts.count, PresetSeeds.all.count - 2)
        try store.restoreDefaultPresets()
        XCTAssertEqual(store.layouts.count, PresetSeeds.all.count)
        XCTAssertNotNil(store.layouts.first(where: { $0.id == PresetSeeds.fullID }))
        XCTAssertNotNil(store.layouts.first(where: { $0.id == PresetSeeds.halvesID }))
    }

    func testRestoreDefaultPresetsIdempotent() throws {
        let store = try LayoutStore(fileURL: fileURL)
        try store.restoreDefaultPresets()
        try store.restoreDefaultPresets()
        XCTAssertEqual(store.layouts.count, PresetSeeds.all.count)
    }

    func testOnChangeFiresAfterMutation() throws {
        let store = try LayoutStore(fileURL: fileURL)
        var fired = 0
        let token = store.onChange { fired += 1 }
        try store.delete(id: PresetSeeds.fullID)
        XCTAssertEqual(fired, 1)
        try store.insert(CustomLayout(
            id: UUID(), name: "X", template: .single, slotProportions: [],
            hotkey: nil, isPresetSeed: false, isModified: false
        ))
        XCTAssertEqual(fired, 2)
        token.cancel()
    }

    func testSimulatedFutureSeedOnlyAddsNewUUID() throws {
        let store = try LayoutStore(fileURL: fileURL)
        try store.delete(id: PresetSeeds.fullID)
        XCTAssertEqual(store.layouts.count, PresetSeeds.all.count - 1)

        let newSeedID = UUID(uuidString: "11111111-0099-0000-0000-000000000099")!
        let newSeed = CustomLayout(
            id: newSeedID, name: "New V0.3 Preset", template: .single, slotProportions: [],
            hotkey: nil, isPresetSeed: true, isModified: false
        )
        try store.applyFutureSeeds(candidates: [newSeed])
        XCTAssertEqual(store.layouts.count, PresetSeeds.all.count)
        XCTAssertNotNil(store.layouts.first(where: { $0.id == newSeedID }))
        XCTAssertNil(store.layouts.first(where: { $0.id == PresetSeeds.fullID }),
                     "deleted seed must not come back")

        // Idempotent
        try store.applyFutureSeeds(candidates: [newSeed])
        XCTAssertEqual(store.layouts.count, PresetSeeds.all.count)
    }

    // MARK: - Hotkey conflict (M7 block-save)

    func testAssignHotkeyBlocksConflict() throws {
        let store = try LayoutStore(fileURL: fileURL)
        let halvesChord = HotkeyBinding(
            keyCode: UInt32(kVK_ANSI_2), modifiers: [.command, .control]
        )
        var fullCopy = store.layouts.first(where: { $0.id == PresetSeeds.fullID })!
        let originalFullHotkey = fullCopy.hotkey
        fullCopy.hotkey = halvesChord
        XCTAssertThrowsError(try store.update(fullCopy)) { err in
            XCTAssertEqual(err as? LayoutStoreError,
                           .hotkeyConflict(existingResource: "Halves"))
        }
        XCTAssertEqual(
            store.layouts.first(where: { $0.id == PresetSeeds.fullID })?.hotkey,
            originalFullHotkey,
            "Full's hotkey must be unchanged after a rejected update"
        )
    }

    func testAssignHotkeyToOwnIDIsNotConflict() throws {
        let store = try LayoutStore(fileURL: fileURL)
        var halves = store.layouts.first(where: { $0.id == PresetSeeds.halvesID })!
        let newChord = HotkeyBinding(
            keyCode: UInt32(kVK_ANSI_J), modifiers: [.command, .control]
        )
        halves.hotkey = newChord
        try store.update(halves)
        // Re-update with the same chord — must not be flagged as a conflict.
        try store.update(halves)
        XCTAssertEqual(store.layouts.first(where: { $0.id == PresetSeeds.halvesID })?.hotkey,
                       newChord)
    }

    func testNilHotkeyAlwaysAllowed() throws {
        let store = try LayoutStore(fileURL: fileURL)
        var halves = store.layouts.first(where: { $0.id == PresetSeeds.halvesID })!
        halves.hotkey = nil
        try store.update(halves)
        XCTAssertNil(store.layouts.first(where: { $0.id == PresetSeeds.halvesID })?.hotkey)
    }
}

// MARK: - V0.4 cross-store hotkey conflict (two-phase setter — §3)

extension LayoutStoreTests {
    func testUpdateThrowsOnExternalWorkspaceHotkeyConflict() throws {
        // Construct with default no-op probe; then install the real probe
        // that simulates a Workspace "Coding" owning ⌘⌥1.
        let store = try LayoutStore(fileURL: fileURL)
        store.setHotkeyConflictProbe { chord in
            chord.keyCode == 18 && chord.modifiers == [.command, .option] ? "Coding" : nil
        }
        var halves = store.layouts.first { $0.name == "Halves" }!
        halves.hotkey = HotkeyBinding(keyCode: 18, modifiers: [.command, .option])  // ⌘⌥1

        XCTAssertThrowsError(try store.update(halves)) { error in
            guard case LayoutStoreError.hotkeyConflict(let resource) = error else {
                return XCTFail("Expected .hotkeyConflict, got \(error)")
            }
            XCTAssertEqual(resource, "Coding")
        }
    }

    func testSetHotkeyConflictProbeReplacesPrior() throws {
        // Confirm the setter replaces, not accumulates — last-writer-wins.
        let store = try LayoutStore(fileURL: fileURL)
        store.setHotkeyConflictProbe { _ in "FirstProbe" }
        store.setHotkeyConflictProbe { _ in nil }  // should override
        var halves = store.layouts.first { $0.name == "Halves" }!
        halves.hotkey = HotkeyBinding(keyCode: 99, modifiers: [.command, .option])  // unused chord
        XCTAssertNoThrow(try store.update(halves))
    }
}
