import XCTest
import Carbon.HIToolbox
@testable import SceneCore

final class PresetSeedsTests: XCTestCase {
    func testSeedNamesMatchV01() {
        // Covers the first 7 seeds (V0.1). V0.4 adds 3 more vertical seeds
        // validated separately in `testMainSideVerticalSeed` etc.
        let expected = [
            "Full",
            "Halves",
            "Thirds",
            "Quads",
            "Main + Side",
            "LeftSplit + Right",
            "Left + RightSplit",
        ]
        XCTAssertEqual(PresetSeeds.all.prefix(7).map(\.name), expected)
    }

    func testAllSeedsMarkedAsPresetAndUnmodified() {
        for seed in PresetSeeds.all {
            XCTAssertTrue(seed.isPresetSeed, "\(seed.name) should be marked isPresetSeed")
            XCTAssertFalse(seed.isModified, "\(seed.name) should be unmodified")
        }
    }

    func testStableUUIDs() {
        let firstIDs = PresetSeeds.all.map(\.id)
        let secondIDs = PresetSeeds.all.map(\.id)
        XCTAssertEqual(firstIDs, secondIDs)
    }

    func testDefaultHotkeysCmdShift1Through7() {
        let expectedKeyCodes: [UInt32] = [
            UInt32(kVK_ANSI_1),
            UInt32(kVK_ANSI_2),
            UInt32(kVK_ANSI_3),
            UInt32(kVK_ANSI_4),
            UInt32(kVK_ANSI_5),
            UInt32(kVK_ANSI_6),
            UInt32(kVK_ANSI_7),
        ]
        // Sanity: per the plan, Carbon kVK_ANSI_1..7 = [18, 19, 20, 21, 23, 22, 26]
        XCTAssertEqual(expectedKeyCodes, [18, 19, 20, 21, 23, 22, 26])

        for (seed, expectedKey) in zip(PresetSeeds.all.prefix(7), expectedKeyCodes) {
            guard let hk = seed.hotkey else {
                XCTFail("\(seed.name) missing default hotkey")
                continue
            }
            XCTAssertEqual(hk.keyCode, expectedKey, "\(seed.name) keyCode mismatch")
            XCTAssertEqual(hk.modifiers, [.command, .control], "\(seed.name) modifiers mismatch")
        }
    }

    func testSeedSlotsMatchV01Layouts() {
        // Pin only the V0.1 seed prefix to V0.1's hard-coded `Layout.all`.
        // V0.4 vertical seeds are validated in `testMainSideVerticalSeed` etc.
        XCTAssertGreaterThanOrEqual(PresetSeeds.all.count, Layout.all.count)
        for (seed, v01) in zip(PresetSeeds.all.prefix(Layout.all.count), Layout.all) {
            let computed = seed.template.slots(proportions: seed.slotProportions)
            XCTAssertEqual(
                computed.count, v01.slots.count,
                "slot count mismatch for \(seed.name)"
            )
            for (i, (a, b)) in zip(computed, v01.slots).enumerated() {
                XCTAssertEqual(Double(a.rect.minX),   Double(b.rect.minX),   accuracy: 1e-9, "\(seed.name) slot[\(i)] minX")
                XCTAssertEqual(Double(a.rect.minY),   Double(b.rect.minY),   accuracy: 1e-9, "\(seed.name) slot[\(i)] minY")
                XCTAssertEqual(Double(a.rect.width),  Double(b.rect.width),  accuracy: 1e-9, "\(seed.name) slot[\(i)] width")
                XCTAssertEqual(Double(a.rect.height), Double(b.rect.height), accuracy: 1e-9, "\(seed.name) slot[\(i)] height")
            }
        }
    }

    // MARK: - V0.4 vertical seeds

    func testAllContainsTenSeeds() {
        XCTAssertEqual(PresetSeeds.all.count, 10,
            "V0.4 expects 7 V0.1 seeds + 3 V0.4 vertical seeds = 10 total")
    }

    func testMainSideVerticalSeed() {
        guard let seed = PresetSeeds.all.first(where: { $0.id == PresetSeeds.mainSideVerticalID }) else {
            return XCTFail("Main + Side (Vertical) seed missing")
        }
        XCTAssertEqual(seed.name, "Main + Side (Vertical)")
        XCTAssertEqual(seed.template, .twoRow)
        XCTAssertEqual(seed.slotProportions, [0.7])
        XCTAssertEqual(seed.hotkey?.modifiers, [.command, .control])
        XCTAssertEqual(seed.hotkey?.keyCode, UInt32(kVK_ANSI_8))
        XCTAssertTrue(seed.isPresetSeed)
        XCTAssertFalse(seed.isModified)
    }

    func testHalvesVerticalSeed() {
        guard let seed = PresetSeeds.all.first(where: { $0.id == PresetSeeds.halvesVerticalID }) else {
            return XCTFail("Halves (Vertical) seed missing")
        }
        XCTAssertEqual(seed.name, "Halves (Vertical)")
        XCTAssertEqual(seed.template, .twoRow)
        XCTAssertEqual(seed.slotProportions, [0.5])
        XCTAssertEqual(seed.hotkey?.keyCode, UInt32(kVK_ANSI_9))
    }

    func testThirdsVerticalSeed() {
        guard let seed = PresetSeeds.all.first(where: { $0.id == PresetSeeds.thirdsVerticalID }) else {
            return XCTFail("Thirds (Vertical) seed missing")
        }
        XCTAssertEqual(seed.name, "Thirds (Vertical)")
        XCTAssertEqual(seed.template, .threeRow)
        XCTAssertEqual(seed.slotProportions.count, 2)
        XCTAssertEqual(Double(seed.slotProportions[0]), 1.0/3.0, accuracy: 0.0001)
        XCTAssertEqual(Double(seed.slotProportions[1]), 2.0/3.0, accuracy: 0.0001)
        XCTAssertEqual(seed.hotkey?.keyCode, UInt32(kVK_ANSI_0))
    }

    func testVerticalSeedIDsAreStable() {
        // V0.4 safety net — UUIDs are persisted in users' layouts.json.
        // Changing these breaks migration. These are the one-way locks.
        XCTAssertEqual(PresetSeeds.mainSideVerticalID.uuidString, "11111111-0008-0000-0000-000000000008")
        XCTAssertEqual(PresetSeeds.halvesVerticalID.uuidString,   "11111111-0009-0000-0000-000000000009")
        XCTAssertEqual(PresetSeeds.thirdsVerticalID.uuidString,   "11111111-000A-0000-0000-00000000000A")
    }

    func testVerticalSeedHotkeysDoNotCollideWithV01Seeds() {
        // ⌘⇧1-7 are the V0.1 seeds; ⌘⇧8/9/0 are the V0.4 vertical seeds.
        let all = PresetSeeds.all
        let chords = all.compactMap { $0.hotkey }
        for i in 0..<chords.count {
            for j in (i + 1)..<chords.count {
                XCTAssertFalse(chords[i].conflicts(with: chords[j]),
                    "Preset seeds \(all[i].name) and \(all[j].name) share a hotkey")
            }
        }
    }
}
