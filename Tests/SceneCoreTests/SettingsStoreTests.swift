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

        // The store should have rewritten the file with version 2 + dragSwap
        let raw = try Data(contentsOf: fileURL)
        let rewrittenString = String(data: raw, encoding: .utf8) ?? ""
        XCTAssertTrue(rewrittenString.contains("\"version\" : 2"),
                      "migration should upgrade version field to 2")
        XCTAssertTrue(rewrittenString.contains("dragSwap"),
                      "migration should add dragSwap field")
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
