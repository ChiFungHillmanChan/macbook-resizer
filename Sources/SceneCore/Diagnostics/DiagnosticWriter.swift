import Foundation

/// Writes diagnostic entries to JSON Lines on disk, off the main thread.
///
/// Architecture (per CLAUDE plan, R2-1): exactly one `AsyncStream` and
/// one consumer `Task`. `enqueue(_:)` is sync and `nonisolated`, simply
/// yielding to the continuation — no `Task {}` is created per call,
/// so there is no fire-and-forget that could race `drain()`.
///
/// `drain()` finishes the stream and awaits the consumer. Every entry
/// `enqueue` accepted has either been written or discarded by the time
/// drain returns; subsequent `setEnabled(false)` cleanup can safely
/// delete files without worrying about a delayed write recreating them.
public final class DiagnosticWriter: @unchecked Sendable {
    private let continuation: AsyncStream<DiagnosticEntry>.Continuation
    private let consumeTask: Task<Void, Never>
    private let state: WriterState

    public init(directory: URL, clock: DiagnosticClock = SystemDiagnosticClock()) {
        let (stream, cont) = AsyncStream<DiagnosticEntry>.makeStream(
            bufferingPolicy: .unbounded
        )
        self.continuation = cont
        let state = WriterState(directory: directory, clock: clock)
        self.state = state
        self.consumeTask = Task.detached(priority: .utility) {
            for await entry in stream {
                await state.handle(entry: entry)
            }
            await state.close()
        }
    }

    /// Sync, fast, callable from any thread or actor. Yields to the
    /// AsyncStream's internal queue; consumer task picks it up.
    public func enqueue(_ entry: DiagnosticEntry) {
        continuation.yield(entry)
    }

    /// Closes the stream and waits for every accepted entry to land on
    /// disk. After return, the writer is permanently quiesced.
    public func drain() async {
        continuation.finish()
        await consumeTask.value
    }

    /// Removes every diagnostic artifact under the writer's directory.
    /// Caller must `await drain()` first to guarantee no in-flight write
    /// can re-create files. Idempotent.
    public func deleteAllArtifacts() async {
        await state.deleteAllArtifacts()
    }

    /// Currently-active file URL (mostly for tests).
    public func activeFileURL() async -> URL? {
        await state.activeFileURL
    }
}

// MARK: - WriterState

/// Actor that owns all mutable file-handle state. The single
/// `consumeTask` in `DiagnosticWriter` is the only caller of `handle`,
/// `close`, and `deleteAllArtifacts`, so per-method serialization comes
/// from the actor model directly.
actor WriterState {
    private let directory: URL
    private let clock: DiagnosticClock
    private var currentDay: String?
    private var currentURL: URL?
    private var currentHandle: FileHandle?
    private var currentSize: Int = 0
    private var lastBudgetSweep: Date?

    private static let budgetSweepInterval: TimeInterval = 30 // seconds

    init(directory: URL, clock: DiagnosticClock) {
        self.directory = directory
        self.clock = clock
    }

    var activeFileURL: URL? { currentURL }

    func handle(entry: DiagnosticEntry) async {
        let day = clock.dayString(for: entry.ts)
        if currentDay != day {
            await rotate(toDay: day)
        }
        await appendLine(entry: entry)
        if currentSize > DiagnosticBudget.activeFileMaxBytes {
            await truncateActive()
        }
        await maybeSweepBudget()
    }

    func close() async {
        try? currentHandle?.close()
        currentHandle = nil
    }

    func deleteAllArtifacts() async {
        try? currentHandle?.close()
        currentHandle = nil
        currentURL = nil
        currentDay = nil
        currentSize = 0
        let fm = FileManager.default
        if let entries = try? DiagnosticBudget.diagnosticFiles(in: directory) {
            for e in entries { try? fm.removeItem(at: e.url) }
        }
    }

    // MARK: - Internal

    private func rotate(toDay newDay: String) async {
        // 1. Compress whatever active file we had open.
        if let oldURL = currentURL {
            try? currentHandle?.close()
            currentHandle = nil
            try? DiagnosticBudget.compressFile(at: oldURL)
        }

        // 2. Open / create the new active file.
        let fm = FileManager.default
        try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let newURL = directory.appendingPathComponent(
            "\(DiagnosticBudget.filenamePrefix)\(newDay).\(DiagnosticBudget.activeExtension)"
        )
        if !fm.fileExists(atPath: newURL.path) {
            fm.createFile(atPath: newURL.path, contents: nil)
        }
        currentURL = newURL
        currentDay = newDay
        currentHandle = try? FileHandle(forWritingTo: newURL)
        try? currentHandle?.seekToEnd()
        currentSize = (try? fm.attributesOfItem(atPath: newURL.path)[.size] as? Int) ?? 0

        // 3. Apply retention + budget on rotation (cheap, same fs walk).
        try? DiagnosticBudget.removeOlderThan(
            directory: directory,
            days: DiagnosticBudget.retentionDays,
            now: clock.now()
        )
        try? DiagnosticBudget.applyTotalBudget(directory: directory)
    }

    private func appendLine(entry: DiagnosticEntry) async {
        guard let handle = currentHandle else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard var data = try? encoder.encode(entry) else { return }
        data.append(0x0A)
        do {
            try handle.write(contentsOf: data)
            currentSize += data.count
        } catch {
            // Best-effort: a write failure during rotation/permission
            // change is recoverable on the next entry.
        }
    }

    private func truncateActive() async {
        guard let url = currentURL else { return }
        try? currentHandle?.close()
        currentHandle = nil
        try? DiagnosticBudget.truncateActiveFile(
            at: url,
            keepLastBytes: DiagnosticBudget.activeFileMaxBytes
        )
        currentHandle = try? FileHandle(forWritingTo: url)
        try? currentHandle?.seekToEnd()
        currentSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
    }

    private func maybeSweepBudget() async {
        let now = clock.now()
        if let last = lastBudgetSweep,
           now.timeIntervalSince(last) < Self.budgetSweepInterval {
            return
        }
        lastBudgetSweep = now
        try? DiagnosticBudget.applyTotalBudget(directory: directory)
    }
}
