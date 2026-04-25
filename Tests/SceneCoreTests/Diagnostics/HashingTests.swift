import XCTest
@testable import SceneCore

final class HashingTests: XCTestCase {
    func testSameSaltSameInputProducesSameHash() {
        let salt = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        let h = DiagnosticHasher(salt: salt)
        XCTAssertEqual(h.hash("com.tinyspeck.slackmacgap"), h.hash("com.tinyspeck.slackmacgap"))
    }

    func testDifferentSaltProducesDifferentHash() {
        let a = DiagnosticHasher(salt: Data([0x01, 0x02, 0x03]))
        let b = DiagnosticHasher(salt: Data([0x04, 0x05, 0x06]))
        XCTAssertNotEqual(a.hash("Slack"), b.hash("Slack"))
    }

    func testDifferentInputProducesDifferentHash() {
        let h = DiagnosticHasher(salt: Data([0x01]))
        XCTAssertNotEqual(h.hash("Slack"), h.hash("Discord"))
    }

    func testHashIsBase64URLNoPadding() {
        let h = DiagnosticHasher(salt: Data([0x42]))
        let token = h.hash("anything")
        XCTAssertFalse(token.contains("="))
        XCTAssertFalse(token.contains("+"))
        XCTAssertFalse(token.contains("/"))
        // 8 raw bytes → 64 bits → 11 base64url chars (after stripping '=' padding)
        XCTAssertEqual(token.count, 11)
    }

    func testHashIDDoesNotLeakSalt() {
        let salt = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        let h = DiagnosticHasher(salt: salt)
        let id = h.hashID()
        // hashID has same length as a regular hash and same character set
        XCTAssertEqual(id.count, 11)
        // Salt's raw bytes do not appear in hashID's UTF-8
        let saltAsString = String(data: salt, encoding: .ascii) ?? ""
        if !saltAsString.isEmpty {
            XCTAssertFalse(id.contains(saltAsString))
        }
    }

    func testHashIDStableAcrossInstancesWithSameSalt() {
        let salt = Data([0xAA, 0xBB, 0xCC])
        let a = DiagnosticHasher(salt: salt)
        let b = DiagnosticHasher(salt: salt)
        XCTAssertEqual(a.hashID(), b.hashID())
    }
}
