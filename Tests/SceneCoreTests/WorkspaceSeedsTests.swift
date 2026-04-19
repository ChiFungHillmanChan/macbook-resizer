import XCTest
@testable import SceneCore
import Carbon.HIToolbox

final class WorkspaceSeedsTests: XCTestCase {
    func testAllContainsFourSeeds() {
        XCTAssertEqual(WorkspaceSeeds.all.count, 4)
    }

    func testSeedNames() {
        let names = WorkspaceSeeds.all.map { $0.name }
        XCTAssertEqual(names, ["Coding", "Meeting", "Reading", "Streaming"])
    }

    func testSeedIDsAreStable() {
        XCTAssertEqual(WorkspaceSeeds.codingID.uuidString,    "22222222-0001-0000-0000-000000000001")
        XCTAssertEqual(WorkspaceSeeds.meetingID.uuidString,   "22222222-0002-0000-0000-000000000002")
        XCTAssertEqual(WorkspaceSeeds.readingID.uuidString,   "22222222-0003-0000-0000-000000000003")
        XCTAssertEqual(WorkspaceSeeds.streamingID.uuidString, "22222222-0004-0000-0000-000000000004")
    }

    func testSeedHotkeys() {
        // ⌘⌥1-4 reserved for the 4 Workspace seeds.
        let keys = WorkspaceSeeds.all.compactMap { $0.hotkey }
        XCTAssertEqual(keys.count, 4)
        XCTAssertTrue(keys.allSatisfy { $0.modifiers == [.command, .option] })
        let codes = keys.map { Int($0.keyCode) }
        XCTAssertEqual(codes.sorted(), [kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4].sorted())
    }

    func testSeedsHaveEmptyAppListsByDefault() {
        for seed in WorkspaceSeeds.all {
            XCTAssertTrue(seed.appsToLaunch.isEmpty, "\(seed.name) must ship with empty appsToLaunch")
            XCTAssertTrue(seed.appsToQuit.isEmpty,   "\(seed.name) must ship with empty appsToQuit")
        }
    }

    func testSeedsHaveNoTriggersByDefault() {
        for seed in WorkspaceSeeds.all {
            XCTAssertTrue(seed.triggers.isEmpty, "\(seed.name) must ship with empty triggers (user configures)")
        }
    }

    func testSeedLayoutIDsMatchPresetSeeds() {
        // Ensures seeded Workspaces reference existing preset layouts (not orphans).
        let presetIDs = Set(PresetSeeds.all.map { $0.id })
        for seed in WorkspaceSeeds.all {
            XCTAssertTrue(presetIDs.contains(seed.layoutID),
                "\(seed.name) references orphan layoutID \(seed.layoutID)")
        }
    }

    func testIsPresetSeedTrue() {
        XCTAssertTrue(WorkspaceSeeds.all.allSatisfy { $0.isPresetSeed })
        XCTAssertFalse(WorkspaceSeeds.all.contains { $0.isModified })
    }
}
