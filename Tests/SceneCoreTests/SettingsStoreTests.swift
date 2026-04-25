import XCTest
@testable import SceneCore

final class SettingsStoreTests: XCTestCase {
    private var fileURL: URL!

    override func setUpWithError() throws {
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("scene-settings-tests-\(UUID().uuidString).json")
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    func testFirstLaunchUsesDefaults() throws {
        let store = try SettingsStore(fileURL: fileURL)
        XCTAssertEqual(store.animation, AnimationConfig.default)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path),
                      "settings file should be created on first launch")
    }

    func testUpdatePersistsAndReloads() throws {
        let store = try SettingsStore(fileURL: fileURL)
        let updated = AnimationConfig(enabled: false, durationMs: 350, easing: .spring)
        try store.setAnimation(updated)
        XCTAssertEqual(store.animation, updated)

        let reloaded = try SettingsStore(fileURL: fileURL)
        XCTAssertEqual(reloaded.animation, updated)
        XCTAssertEqual(reloaded.animation.durationMs, 350)
        XCTAssertEqual(reloaded.animation.easing, .spring)
        XCTAssertFalse(reloaded.animation.enabled)
    }

    func testOnChangeFires() throws {
        let store = try SettingsStore(fileURL: fileURL)
        var fired = 0
        let token = store.onChange { fired += 1 }

        try store.setAnimation(AnimationConfig(enabled: true, durationMs: 200, easing: .linear))
        XCTAssertEqual(fired, 1)

        token.cancel()
        try store.setAnimation(AnimationConfig(enabled: true, durationMs: 220, easing: .linear))
        XCTAssertEqual(fired, 1, "observer should not fire after cancel")
    }
}

// MARK: - V0.3 schema v2 migration

extension SettingsStoreTests {
    func testFirstLaunchSeedsDragSwapDefault() throws {
        let store = try SettingsStore(fileURL: fileURL)
        XCTAssertEqual(store.dragSwap, DragSwapConfig.default)
    }

    func testSetDragSwapPersistsAndReloads() throws {
        let store = try SettingsStore(fileURL: fileURL)
        let updated = DragSwapConfig(enabled: false, distanceThresholdPt: 55)
        try store.setDragSwap(updated)
        XCTAssertEqual(store.dragSwap, updated)

        let reloaded = try SettingsStore(fileURL: fileURL)
        XCTAssertEqual(reloaded.dragSwap, updated)
    }

    func testLoadingV1FileMigratesToV2WithDefaultDragSwap() throws {
        // Simulate V0.2 settings file (no dragSwap field, version: 1)
        let v1json = #"""
        {"version":1,"animation":{"enabled":true,"durationMs":250,"easing":"easeOut"}}
        """#.data(using: .utf8)!
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try v1json.write(to: fileURL)

        let store = try SettingsStore(fileURL: fileURL)
        XCTAssertEqual(store.dragSwap, DragSwapConfig.default)
        XCTAssertEqual(store.animation, AnimationConfig.default)

        // The store should have rewritten the file with the current
        // version (V0.6: 3) + dragSwap + diagnosticsEnabled fields.
        let raw = try Data(contentsOf: fileURL)
        let rewrittenString = String(data: raw, encoding: .utf8) ?? ""
        XCTAssertTrue(rewrittenString.contains("\"version\" : \(SettingsStore.currentVersion)"),
                      "migration should upgrade version field to current schema")
        XCTAssertTrue(rewrittenString.contains("dragSwap"),
                      "migration should add dragSwap field")
        XCTAssertTrue(rewrittenString.contains("diagnosticsEnabled"),
                      "migration should add V0.6 diagnosticsEnabled field")
    }

    // MARK: - V0.6 diagnostics toggle

    func testFreshStoreDefaultsDiagnosticsEnabledTrue() throws {
        let store = try SettingsStore(fileURL: fileURL)
        XCTAssertTrue(store.diagnosticsEnabled)
    }

    func testV2FileMigratesToV3WithDiagnosticsEnabled() throws {
        // Simulate V0.5.x settings file (version 2, no diagnosticsEnabled).
        let v2json = #"""
        {"version":2,"animation":{"enabled":true,"durationMs":250,"easing":"easeOut"},"dragSwap":{"enabled":true,"distanceThresholdPt":40}}
        """#.data(using: .utf8)!
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try v2json.write(to: fileURL)
        let store = try SettingsStore(fileURL: fileURL)
        XCTAssertTrue(store.diagnosticsEnabled, "V2 → V3 migration defaults diagnosticsEnabled = true")
        let raw = try Data(contentsOf: fileURL)
        let rewritten = String(data: raw, encoding: .utf8) ?? ""
        XCTAssertTrue(rewritten.contains("\"version\" : 3"))
        XCTAssertTrue(rewritten.contains("diagnosticsEnabled"))
    }

    func testSetDiagnosticsEnabledPersistsAndNotifies() throws {
        let store = try SettingsStore(fileURL: fileURL)
        var fired = 0
        let token = store.onChange { fired += 1 }
        try store.setDiagnosticsEnabled(false)
        XCTAssertFalse(store.diagnosticsEnabled)
        XCTAssertEqual(fired, 1)
        // Re-load from disk to confirm persistence
        let reopened = try SettingsStore(fileURL: fileURL)
        XCTAssertFalse(reopened.diagnosticsEnabled)
        token.cancel()
    }

    func testDragSwapOnChangeFires() throws {
        let store = try SettingsStore(fileURL: fileURL)
        var fired = 0
        let token = store.onChange { fired += 1 }
        try store.setDragSwap(DragSwapConfig(enabled: false, distanceThresholdPt: 60))
        XCTAssertEqual(fired, 1)
        token.cancel()
    }
}
