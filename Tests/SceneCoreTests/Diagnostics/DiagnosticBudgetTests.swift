import XCTest
@testable import SceneCore

final class DiagnosticBudgetTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("scene-budget-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    // MARK: - parseDay

    func testParseDayHappyPath() {
        XCTAssertEqual(DiagnosticBudget.parseDay(fromName: "events-2026-04-25.jsonl"), "2026-04-25")
        XCTAssertEqual(DiagnosticBudget.parseDay(fromName: "events-2026-04-25.jsonl.gz"), "2026-04-25")
    }

    func testParseDayRejectsUnrelated() {
        XCTAssertNil(DiagnosticBudget.parseDay(fromName: "settings.json"))
        XCTAssertNil(DiagnosticBudget.parseDay(fromName: "events-2026-04-25.txt"))
        XCTAssertNil(DiagnosticBudget.parseDay(fromName: "events-bad.jsonl"))
    }

    // MARK: - Truncation

    func testTruncateBelowCapNoOp() throws {
        let url = dir.appendingPathComponent("events-2026-04-25.jsonl")
        let payload = Data("hello\n".utf8)
        try payload.write(to: url, options: .atomic)
        try DiagnosticBudget.truncateActiveFile(at: url, keepLastBytes: 100)
        XCTAssertEqual(try Data(contentsOf: url), payload)
    }

    func testTruncateKeepsLastNewlineBoundedTail() throws {
        let url = dir.appendingPathComponent("events-2026-04-25.jsonl")
        // 5 lines of 30 bytes each (29 'x' + '\n') = 150 bytes total
        var blob = Data()
        for _ in 0..<5 {
            blob.append(Data((String(repeating: "x", count: 29) + "\n").utf8))
        }
        try blob.write(to: url, options: .atomic)
        try DiagnosticBudget.truncateActiveFile(at: url, keepLastBytes: 60)
        let after = try Data(contentsOf: url)
        // tailStart = 150 - 60 = 90. First newline AT-OR-AFTER byte 90 sits
        // at byte 119 (end of line 4), so we drop everything through it and
        // keep just the final 30-byte line. This guarantees no partial line
        // at the head of the truncated file.
        XCTAssertEqual(after.count, 30)
        XCTAssertEqual(after.first, UInt8(ascii: "x"))
        XCTAssertEqual(after.last, 0x0A)
    }

    func testTruncateNoNewlineEmptiesFile() throws {
        let url = dir.appendingPathComponent("events-2026-04-25.jsonl")
        try Data(repeating: 0x41, count: 200).write(to: url, options: .atomic)
        try DiagnosticBudget.truncateActiveFile(at: url, keepLastBytes: 50)
        XCTAssertEqual((try? Data(contentsOf: url))?.count, 0)
    }

    // MARK: - Retention

    func testRemoveOlderThanByDay() throws {
        let fm = FileManager.default
        for day in ["2026-04-18", "2026-04-19", "2026-04-25"] {
            let url = dir.appendingPathComponent("events-\(day).jsonl.gz")
            fm.createFile(atPath: url.path, contents: Data())
        }
        // now=2026-04-25, days=7 → cutoff=2026-04-18 (inclusive — equal-day kept)
        let now = DiagnosticBudget.dayFormatter.date(from: "2026-04-25")!
        try DiagnosticBudget.removeOlderThan(directory: dir, days: 7, now: now)
        let files = try DiagnosticBudget.diagnosticFiles(in: dir)
            .map(\.day).sorted()
        XCTAssertEqual(files, ["2026-04-18", "2026-04-19", "2026-04-25"])
    }

    func testRemoveOlderThanDeletesAncient() throws {
        let fm = FileManager.default
        for day in ["2025-01-01", "2026-04-18", "2026-04-25"] {
            let url = dir.appendingPathComponent("events-\(day).jsonl.gz")
            fm.createFile(atPath: url.path, contents: Data())
        }
        let now = DiagnosticBudget.dayFormatter.date(from: "2026-04-25")!
        try DiagnosticBudget.removeOlderThan(directory: dir, days: 7, now: now)
        let files = try DiagnosticBudget.diagnosticFiles(in: dir).map(\.day).sorted()
        XCTAssertEqual(files, ["2026-04-18", "2026-04-25"])
    }

    // MARK: - Total budget

    func testApplyTotalBudgetEvictsOldestRotatedFirst() throws {
        let fm = FileManager.default
        // 4 rotated files at 1 KB each = 4 KB total. Active = 0 bytes.
        let oneKB = Data(repeating: 0x42, count: 1024)
        for day in ["2026-04-20", "2026-04-21", "2026-04-22", "2026-04-23"] {
            try oneKB.write(to: dir.appendingPathComponent("events-\(day).jsonl.gz"), options: .atomic)
        }
        let activeURL = dir.appendingPathComponent("events-2026-04-24.jsonl")
        fm.createFile(atPath: activeURL.path, contents: Data())

        // Cap at 2 KB — should evict 04-20 and 04-21 (oldest two)
        try DiagnosticBudget.applyTotalBudget(directory: dir, budgetBytes: 2_048)
        let remaining = try DiagnosticBudget.diagnosticFiles(in: dir).map(\.day).sorted()
        XCTAssertEqual(remaining, ["2026-04-22", "2026-04-23", "2026-04-24"])
    }

    func testApplyTotalBudgetPreservesActiveFile() throws {
        let fm = FileManager.default
        // Active file is 5 KB ALONE; budget is 1 KB. Without the
        // preservation rule we'd be stuck (can't delete .jsonl).
        let url = dir.appendingPathComponent("events-2026-04-25.jsonl")
        try Data(repeating: 0x42, count: 5_000).write(to: url, options: .atomic)
        try DiagnosticBudget.applyTotalBudget(directory: dir, budgetBytes: 1_000)
        XCTAssertTrue(fm.fileExists(atPath: url.path))
    }

    // MARK: - Compress

    func testCompressFileProducesGzAndRemovesOriginal() throws {
        let original = dir.appendingPathComponent("events-2026-04-25.jsonl")
        let payload = Data("{\"line\":1}\n{\"line\":2}\n".utf8)
        try payload.write(to: original, options: .atomic)
        try DiagnosticBudget.compressFile(at: original)
        XCTAssertFalse(FileManager.default.fileExists(atPath: original.path))
        let gz = dir.appendingPathComponent("events-2026-04-25.jsonl.gz")
        XCTAssertTrue(FileManager.default.fileExists(atPath: gz.path))
        // Inspect via system gunzip
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/gunzip")
        proc.arguments = ["-c", gz.path]   // write to stdout
        let pipe = Pipe()
        proc.standardOutput = pipe
        try proc.run()
        proc.waitUntilExit()
        let out = pipe.fileHandleForReading.readDataToEndOfFile()
        XCTAssertEqual(out, payload)
    }
}
