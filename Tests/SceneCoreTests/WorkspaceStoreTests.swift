import XCTest
@testable import SceneCore

final class WorkspaceStoreTests: XCTestCase {
    private var tempDir: URL!
    private var fileURL: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        fileURL = tempDir.appendingPathComponent("workspaces.json")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - First-launch seeding

    func testFirstLaunchSeedsFourWorkspaces() throws {
        let store = try WorkspaceStore(fileURL: fileURL, hotkeyConflictProbe: { _ in nil })
        XCTAssertEqual(store.workspaces.count, 4)
        XCTAssertEqual(Set(store.workspaces.map { $0.id }),
                       Set([WorkspaceSeeds.codingID, WorkspaceSeeds.meetingID,
                            WorkspaceSeeds.readingID, WorkspaceSeeds.streamingID]))
    }

    func testFirstLaunchPersists() throws {
        _ = try WorkspaceStore(fileURL: fileURL, hotkeyConflictProbe: { _ in nil })
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        let data = try Data(contentsOf: fileURL)
        XCTAssertGreaterThan(data.count, 100)  // non-empty
    }

    // MARK: - Subsequent launch

    func testSecondLaunchDoesNotReseed() throws {
        let first = try WorkspaceStore(fileURL: fileURL, hotkeyConflictProbe: { _ in nil })
        try first.delete(id: WorkspaceSeeds.meetingID)
        XCTAssertEqual(first.workspaces.count, 3)

        let second = try WorkspaceStore(fileURL: fileURL, hotkeyConflictProbe: { _ in nil })
        XCTAssertEqual(second.workspaces.count, 3)
        XCTAssertFalse(second.workspaces.contains { $0.id == WorkspaceSeeds.meetingID })
    }

    // MARK: - Update / edit

    func testUpdateMarksIsModified() throws {
        let store = try WorkspaceStore(fileURL: fileURL, hotkeyConflictProbe: { _ in nil })
        var coding = store.workspaces.first { $0.id == WorkspaceSeeds.codingID }!
        coding.appsToLaunch = ["com.apple.Safari"]
        try store.update(coding)

        let reloaded = try WorkspaceStore(fileURL: fileURL, hotkeyConflictProbe: { _ in nil })
        let edited = reloaded.workspaces.first { $0.id == WorkspaceSeeds.codingID }!
        XCTAssertEqual(edited.appsToLaunch, ["com.apple.Safari"])
        XCTAssertTrue(edited.isModified)
    }

    // MARK: - Strict update semantics

    func testUpdateThrowsWhenIDNotFound() throws {
        let store = try WorkspaceStore(fileURL: fileURL, hotkeyConflictProbe: { _ in nil })
        let missing = Workspace(
            id: UUID(),  // never added
            name: "Ghost",
            layoutID: PresetSeeds.fullID
        )
        XCTAssertThrowsError(try store.update(missing)) { error in
            guard case WorkspaceStoreError.notFound = error else {
                return XCTFail("Expected .notFound, got \(error)")
            }
        }
        // Confirm the ghost was NOT appended.
        XCTAssertFalse(store.workspaces.contains { $0.id == missing.id })
    }

    // MARK: - Insert duplicate-ID guard

    func testInsertThrowsOnDuplicateID() throws {
        let store = try WorkspaceStore(fileURL: fileURL, hotkeyConflictProbe: { _ in nil })
        let duplicate = Workspace(
            id: WorkspaceSeeds.codingID,  // already seeded
            name: "Imposter",
            layoutID: PresetSeeds.fullID
        )
        XCTAssertThrowsError(try store.insert(duplicate)) { error in
            guard case WorkspaceStoreError.duplicateID(let id) = error else {
                return XCTFail("Expected .duplicateID, got \(error)")
            }
            XCTAssertEqual(id, WorkspaceSeeds.codingID)
        }
        XCTAssertEqual(store.workspaces.count, 4)  // unchanged
    }

    // MARK: - Cross-store hotkey conflict

    func testUpdateThrowsOnInternalHotkeyConflict() throws {
        let store = try WorkspaceStore(fileURL: fileURL, hotkeyConflictProbe: { _ in nil })
        var meeting = store.workspaces.first { $0.id == WorkspaceSeeds.meetingID }!
        // Coding already owns ⌘⌥1 by default
        meeting.hotkey = HotkeyBinding(keyCode: 18, modifiers: [.command, .option])  // ⌘⌥1

        XCTAssertThrowsError(try store.update(meeting)) { error in
            guard case WorkspaceStoreError.hotkeyConflict(let resource) = error else {
                return XCTFail("Expected .hotkeyConflict, got \(error)")
            }
            XCTAssertEqual(resource, "Coding")
        }
    }

    func testUpdateThrowsOnExternalHotkeyConflict() throws {
        // Simulate a layout "Halves" owning ⌘⌃2.
        let store = try WorkspaceStore(
            fileURL: fileURL,
            hotkeyConflictProbe: { chord in
                chord.keyCode == 19 && chord.modifiers == [.command, .control] ? "Halves" : nil
            }
        )
        var coding = store.workspaces.first { $0.id == WorkspaceSeeds.codingID }!
        coding.hotkey = HotkeyBinding(keyCode: 19, modifiers: [.command, .control])

        XCTAssertThrowsError(try store.update(coding)) { error in
            guard case WorkspaceStoreError.hotkeyConflict(let resource) = error else {
                return XCTFail("Expected .hotkeyConflict, got \(error)")
            }
            XCTAssertEqual(resource, "Halves")
        }
    }

    // MARK: - Active workspace

    func testActiveWorkspaceIsSessionOnly() throws {
        let store = try WorkspaceStore(fileURL: fileURL, hotkeyConflictProbe: { _ in nil })
        try store.setActive(WorkspaceSeeds.readingID)
        XCTAssertEqual(store.activeWorkspaceID, WorkspaceSeeds.readingID)

        // `activeWorkspaceID` is intentionally session-only: a reload does not
        // restore it. Otherwise users see a "preselected" workspace on launch
        // even though they did not pick one in the current session.
        let reloaded = try WorkspaceStore(fileURL: fileURL, hotkeyConflictProbe: { _ in nil })
        XCTAssertNil(reloaded.activeWorkspaceID)
    }

    func testSetActiveNilClears() throws {
        let store = try WorkspaceStore(fileURL: fileURL, hotkeyConflictProbe: { _ in nil })
        try store.setActive(WorkspaceSeeds.codingID)
        try store.setActive(nil)
        XCTAssertNil(store.activeWorkspaceID)
    }

    // MARK: - Observation

    func testObservationFiresOnUpdate() throws {
        let store = try WorkspaceStore(fileURL: fileURL, hotkeyConflictProbe: { _ in nil })
        var fireCount = 0
        let token = store.onChange { fireCount += 1 }
        defer { token.cancel() }

        var coding = store.workspaces.first { $0.id == WorkspaceSeeds.codingID }!
        coding.name = "Deep Focus"
        try store.update(coding)

        XCTAssertEqual(fireCount, 1)
    }

    // MARK: - Delete

    func testDeleteRemovesAndPersists() throws {
        let store = try WorkspaceStore(fileURL: fileURL, hotkeyConflictProbe: { _ in nil })
        try store.delete(id: WorkspaceSeeds.streamingID)
        XCTAssertEqual(store.workspaces.count, 3)
        XCTAssertFalse(store.workspaces.contains { $0.id == WorkspaceSeeds.streamingID })

        let reloaded = try WorkspaceStore(fileURL: fileURL, hotkeyConflictProbe: { _ in nil })
        XCTAssertEqual(reloaded.workspaces.count, 3)
    }

    // MARK: - applyFutureSeeds

    func testApplyFutureSeedsAddsOnlyNewUUIDs() throws {
        let store = try WorkspaceStore(fileURL: fileURL, hotkeyConflictProbe: { _ in nil })
        try store.delete(id: WorkspaceSeeds.meetingID)

        // Simulate a "future V0.5 seed" being added to a new all list.
        let futureID = UUID(uuidString: "33333333-0001-0000-0000-000000000001")!
        let futureSeed = Workspace(
            id: futureID, name: "Future",
            layoutID: PresetSeeds.fullID,
            isPresetSeed: true, isModified: false
        )
        try store.applyFutureSeeds(WorkspaceSeeds.all + [futureSeed])

        // Meeting stays deleted; Future is added.
        XCTAssertFalse(store.workspaces.contains { $0.id == WorkspaceSeeds.meetingID })
        XCTAssertTrue(store.workspaces.contains { $0.id == futureID })
    }

    // MARK: - Setter pattern (§3)

    func testSetHotkeyConflictProbeReplacesPrior() throws {
        let store = try WorkspaceStore(fileURL: fileURL, hotkeyConflictProbe: { _ in "FirstProbe" })
        // Override to a no-op probe.
        store.setHotkeyConflictProbe { _ in nil }
        var coding = store.workspaces.first { $0.id == WorkspaceSeeds.codingID }!
        // Use a chord no other workspace owns.
        coding.hotkey = HotkeyBinding(keyCode: 99, modifiers: [.command, .control])
        XCTAssertNoThrow(try store.update(coding))
    }
}
