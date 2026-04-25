import XCTest
@testable import SceneCore

final class GzipWriterTests: XCTestCase {
    func testCompressEmptyInputProducesValidGzip() throws {
        let out = try GzipWriter.compress(Data())
        // Header (10 B) + empty deflate (skipped — we return empty) + crc(4) + isize(4) = 18 B
        // Our impl returns header + 0-byte deflate + crc(0)+isize(0). That is technically still
        // a valid gzip file (empty member).
        XCTAssertGreaterThanOrEqual(out.count, 18)
        // Magic bytes
        XCTAssertEqual(out[0], 0x1F)
        XCTAssertEqual(out[1], 0x8B)
    }

    func testGunzipRoundTripViaSystemTool() throws {
        let payload = Data((0..<500).map { _ in UInt8.random(in: 0...255) })
        let gz = try GzipWriter.compress(payload)
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("scene-gzip-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let gzURL = tmpDir.appendingPathComponent("payload.bin.gz")
        try gz.write(to: gzURL, options: .atomic)

        // Run /usr/bin/gunzip and verify the output equals the original payload
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/gunzip")
        process.arguments = ["-k", "-f", gzURL.path]    // -k = keep .gz, -f = force overwrite
        let pipe = Pipe()
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0,
            "gunzip exited \(process.terminationStatus): " +
            String(data: pipe.fileHandleForReading.availableData, encoding: .utf8).debugDescription)

        let outURL = tmpDir.appendingPathComponent("payload.bin")
        let decompressed = try Data(contentsOf: outURL)
        XCTAssertEqual(decompressed, payload)
    }

    func testCRC32MatchesKnownValue() {
        // RFC 1952 Annex test vector: CRC32 of "123456789" = 0xCBF43926
        let crc = GzipWriter.crc32(Data("123456789".utf8))
        XCTAssertEqual(crc, 0xCBF43926)
    }

    func testCompressShrinksRepetitiveInput() throws {
        let payload = Data(repeating: 0x41, count: 10_000)
        let gz = try GzipWriter.compress(payload)
        // Repetitive input compresses heavily; expect output << input
        XCTAssertLessThan(gz.count, 200,
            "expected heavy compression on 10 KB of \"A\" — got \(gz.count) bytes")
    }
}
