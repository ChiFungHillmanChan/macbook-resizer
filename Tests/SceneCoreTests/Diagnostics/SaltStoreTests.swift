import XCTest
@testable import SceneCore

final class SaltStoreTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("scene-salt-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    func testLoadOrCreateGeneratesWhenMissing() throws {
        let store = SaltStore(directory: dir)
        let salt = try store.loadOrCreate()
        XCTAssertEqual(salt.count, SaltStore.saltByteCount)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.url.path))
    }

    func testLoadOrCreateReturnsExisting() throws {
        let store = SaltStore(directory: dir)
        let first = try store.loadOrCreate()
        let second = try store.loadOrCreate()
        XCTAssertEqual(first, second)
    }

    func testRegenerateProducesDifferentBytes() throws {
        let store = SaltStore(directory: dir)
        let a = try store.loadOrCreate()
        let b = try store.regenerate()
        XCTAssertNotEqual(a, b)
        XCTAssertEqual(b.count, SaltStore.saltByteCount)
    }

    func testFileModeIs0600() throws {
        let store = SaltStore(directory: dir)
        _ = try store.loadOrCreate()
        let attrs = try FileManager.default.attributesOfItem(atPath: store.url.path)
        let perms = attrs[.posixPermissions] as? NSNumber
        XCTAssertEqual(perms?.int16Value, 0o600)
    }

    func testCorruptedFileTriggersRegeneration() throws {
        let store = SaltStore(directory: dir)
        // Write a 5-byte (too-short) salt
        try Data([0x01, 0x02, 0x03, 0x04, 0x05]).write(to: store.url, options: .atomic)
        let salt = try store.loadOrCreate()
        XCTAssertEqual(salt.count, SaltStore.saltByteCount)
    }

    func testDeleteRemovesFile() throws {
        let store = SaltStore(directory: dir)
        _ = try store.loadOrCreate()
        try store.delete()
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.url.path))
    }
}
