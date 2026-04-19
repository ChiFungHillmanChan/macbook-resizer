import XCTest
import Carbon.HIToolbox
@testable import SceneCore

final class PresetSeedsTests: XCTestCase {
    func testHasSevenSeeds() {
        XCTAssertEqual(PresetSeeds.all.count, 7)
    }

    func testSeedNamesMatchV01() {
        let expected = [
            "Full",
            "Halves",
            "Thirds",
            "Quads",
            "Main + Side",
            "LeftSplit + Right",
            "Left + RightSplit",
        ]
        XCTAssertEqual(PresetSeeds.all.map(\.name), expected)
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

        for (seed, expectedKey) in zip(PresetSeeds.all, expectedKeyCodes) {
            guard let hk = seed.hotkey else {
                XCTFail("\(seed.name) missing default hotkey")
                continue
            }
            XCTAssertEqual(hk.keyCode, expectedKey, "\(seed.name) keyCode mismatch")
            XCTAssertEqual(hk.modifiers, [.command, .shift], "\(seed.name) modifiers mismatch")
        }
    }

    func testSeedSlotsMatchV01Layouts() {
        XCTAssertEqual(PresetSeeds.all.count, Layout.all.count)
        for (seed, v01) in zip(PresetSeeds.all, Layout.all) {
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
}
