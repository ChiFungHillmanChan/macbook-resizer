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
