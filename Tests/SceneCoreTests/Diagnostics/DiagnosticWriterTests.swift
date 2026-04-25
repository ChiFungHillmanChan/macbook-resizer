import XCTest
@testable import SceneCore

/// Mutable test clock — wall-clock independent. The actual rotation
/// path uses `entry.ts`, not `clock.now()`, so the clock here is mostly
/// for budget-sweep timing and `removeOlderThan`.
final class FakeDiagnosticClock: DiagnosticClock, @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date

    init(_ initial: Date) { self.current = initial }

    func now() -> Date {
        lock.lock(); defer { lock.unlock() }
        return current
    }

    func advance(by interval: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        current = current.addingTimeInterval(interval)
    }

    func set(_ date: Date) {
        lock.lock(); defer { lock.unlock() }
        current = date
    }
}

final class DiagnosticWriterTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("scene-writer-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private let dummyID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!

    private func entry(_ secondsSinceEpoch: TimeInterval) -> DiagnosticEntry {
        DiagnosticEntry(
            ts: Date(timeIntervalSince1970: secondsSinceEpoch),
            event: .layoutOutcomeInstant(.init(
                layoutID: dummyID, placed: 1, minimized: 0, leftEmpty: 0, failed: 0
            ))
        )
    }

    private func dayURL(_ day: String, gz: Bool = false) -> URL {
        dir.appendingPathComponent("events-\(day).\(gz ? "jsonl.gz" : "jsonl")")
    }

    // MARK: - Race test (R2-1)

    func testEnqueueThenDrainAllOnDisk() async throws {
        let day = DiagnosticBudget.dayFormatter.date(from: "2026-04-25")!
        let clock = FakeDiagnosticClock(day)
        let writer = DiagnosticWriter(directory: dir, clock: clock)

        let count = 100
        let baseTs = day.timeIntervalSince1970
        for i in 0..<count {
            writer.enqueue(entry(baseTs + Double(i)))   // all same UTC day
        }
        await writer.drain()

        let url = dayURL("2026-04-25")
        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.split(separator: "\n", omittingEmptySubsequences: true)
        XCTAssertEqual(lines.count, count, "drain() must wait for every accepted entry")
    }

    func testDrainIsIdempotent() async throws {
        let day = DiagnosticBudget.dayFormatter.date(from: "2026-04-25")!
        let writer = DiagnosticWriter(directory: dir, clock: FakeDiagnosticClock(day))
        writer.enqueue(entry(day.timeIntervalSince1970))
        await writer.drain()
        await writer.drain()  // second call should not crash / hang
    }

    // MARK: - Rotation

    func testRotationOnDayBoundary() async throws {
        let day1 = DiagnosticBudget.dayFormatter.date(from: "2026-04-25")!
        let day2 = DiagnosticBudget.dayFormatter.date(from: "2026-04-26")!
        let writer = DiagnosticWriter(
            directory: dir, clock: FakeDiagnosticClock(day1)
        )

        writer.enqueue(DiagnosticEntry(
            ts: day1, event: .axPermissionChanged(.init(granted: true))
        ))
        writer.enqueue(DiagnosticEntry(
            ts: day2, event: .axPermissionChanged(.init(granted: false))
        ))
        await writer.drain()

        // 2026-04-25 should have been compressed; 2026-04-26 should be active
        XCTAssertFalse(FileManager.default.fileExists(atPath: dayURL("2026-04-25").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dayURL("2026-04-25", gz: true).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dayURL("2026-04-26").path))
    }

    // MARK: - deleteAllArtifacts

    func testDeleteAllArtifactsClearsDirectory() async throws {
        let day = DiagnosticBudget.dayFormatter.date(from: "2026-04-25")!
        let clock = FakeDiagnosticClock(day)
        let writer = DiagnosticWriter(directory: dir, clock: clock)
        for _ in 0..<5 { writer.enqueue(entry(clock.now().timeIntervalSince1970)) }
        await writer.drain()
        XCTAssertGreaterThan(try DiagnosticBudget.diagnosticFiles(in: dir).count, 0)

        // Re-create writer (simulates user toggling off)
        let writer2 = DiagnosticWriter(directory: dir, clock: clock)
        await writer2.drain()
        await writer2.deleteAllArtifacts()
        XCTAssertEqual(try DiagnosticBudget.diagnosticFiles(in: dir).count, 0)
    }

    // MARK: - Lines have flat shape

    func testWrittenLinesAreValidDiagnosticEntryJSON() async throws {
        let day = DiagnosticBudget.dayFormatter.date(from: "2026-04-25")!
        let clock = FakeDiagnosticClock(day)
        let writer = DiagnosticWriter(directory: dir, clock: clock)
        writer.enqueue(entry(day.timeIntervalSince1970))
        await writer.drain()

        let url = dayURL(clock.dayString())
        let content = try String(contentsOf: url, encoding: .utf8)
        let line = content.split(separator: "\n").first.map(String.init) ?? ""
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let entry = try decoder.decode(DiagnosticEntry.self, from: Data(line.utf8))
        if case .layoutOutcomeInstant = entry.event {
            // OK
        } else {
            XCTFail("expected layoutOutcomeInstant")
        }
    }

    // MARK: - Per-file size cap

    func testActiveFileTruncatesAtCap() async throws {
        let day = DiagnosticBudget.dayFormatter.date(from: "2026-04-25")!
        let clock = FakeDiagnosticClock(day)
        let writer = DiagnosticWriter(directory: dir, clock: clock)
        let ts = day.timeIntervalSince1970
        // Each entry is ~150-200 B; pump enough to overflow 100 KB cap
        for i in 0..<800 {
            writer.enqueue(entry(ts + Double(i)))
        }
        await writer.drain()

        let url = dayURL(clock.dayString())
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        XCTAssertLessThanOrEqual(size, DiagnosticBudget.activeFileMaxBytes,
            "active file should be truncated at \(DiagnosticBudget.activeFileMaxBytes) B")
    }
}
