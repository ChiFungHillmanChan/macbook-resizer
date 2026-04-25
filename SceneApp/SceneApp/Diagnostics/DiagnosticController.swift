import Foundation
import SceneCore

/// Composition root for the V0.6 diagnostic pipeline. Owns:
///   - `EventLog`            — in-memory ring buffer (200 entries)
///   - `DiagnosticWriter`    — actor-backed JSONL writer + gzip rotation
///   - `SaltStore`           — `.salt` file (mode 0600), never exported
///   - `DiagnosticHasher`    — string-to-token hashing for export sanitization
///
/// Exposes `sink: DiagnosticSink` for orchestration code (Coordinator,
/// WorkspaceActivator, TriggerSupervisor, etc.). The sink is sync, fast,
/// thread-safe — calls land on the in-RAM ring buffer immediately and
/// on disk via the writer's single AsyncStream consumer.
///
/// `enable()` / `disable()` lifecycle is wired by `SettingsStoreViewModel`
/// in M5. Disabling drains the writer, deletes all artifacts, and rotates
/// the salt so re-enabling produces a fresh hash family.
final class DiagnosticController: @unchecked Sendable {
    let directory: URL
    let eventLog: EventLog
    private let saltStore: SaltStore

    private let lock = NSLock()
    private var _enabled: Bool
    private var _writer: DiagnosticWriter?
    private var _hasher: DiagnosticHasher

    init(directory: URL, initiallyEnabled: Bool = true) throws {
        self.directory = directory
        self.eventLog = EventLog()
        self.saltStore = SaltStore(directory: directory)
        let salt = try saltStore.loadOrCreate()
        self._hasher = DiagnosticHasher(salt: salt)
        self._enabled = initiallyEnabled
        self._writer = initiallyEnabled ? DiagnosticWriter(directory: directory) : nil
    }

    var enabled: Bool {
        lock.lock(); defer { lock.unlock() }
        return _enabled
    }

    var hasher: DiagnosticHasher {
        lock.lock(); defer { lock.unlock() }
        return _hasher
    }

    var sink: DiagnosticSink { ControllerSink(controller: self) }

    func enable() throws {
        lock.lock()
        if _enabled { lock.unlock(); return }
        let salt = try saltStore.regenerate()
        _hasher = DiagnosticHasher(salt: salt)
        _writer = DiagnosticWriter(directory: directory)
        _enabled = true
        lock.unlock()
    }

    /// Drains in-flight writes, removes all `.jsonl[.gz]` files plus the
    /// `.salt`, and clears the in-memory ring buffer. Idempotent.
    func disable() async {
        let writer = takeWriterForDisable()
        await writer?.drain()
        await writer?.deleteAllArtifacts()
        try? saltStore.delete()
    }

    /// Synchronous extraction of the disable-time state — kept out of
    /// the async caller so Swift 6's `lock`/`unlock`-in-async-context
    /// diagnostic stays quiet (the lock never spans an `await`).
    private func takeWriterForDisable() -> DiagnosticWriter? {
        lock.lock(); defer { lock.unlock() }
        let writer = _writer
        _writer = nil
        _enabled = false
        return writer
    }

    /// Snapshots the in-memory ring for the export bundle.
    func recentEntriesSnapshot() -> [DiagnosticEntry] {
        eventLog.snapshot()
    }

    fileprivate func ingest(_ event: DiagnosticEvent) {
        lock.lock()
        let isEnabled = _enabled
        let writer = _writer
        lock.unlock()
        guard isEnabled else { return }
        let entry = DiagnosticEntry(ts: Date(), event: event)
        eventLog.append(entry)
        writer?.enqueue(entry)
    }

    private struct ControllerSink: DiagnosticSink {
        weak var controller: DiagnosticController?
        func log(_ event: DiagnosticEvent) {
            controller?.ingest(event)
        }
    }
}
