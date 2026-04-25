import Foundation

/// In-memory, fixed-capacity ring buffer of recent diagnostic entries.
/// Sync, lock-protected, callable from any thread. Used by the export
/// bundle assembly so the most recent ~200 entries are available even
/// if the on-disk write hasn't yet flushed.
///
/// On overflow, oldest entry is overwritten silently. No notifications
/// fire from `append` — observers are added via `onAppend`.
public final class EventLog: @unchecked Sendable {
    public static let defaultCapacity = 200

    private let lock = NSLock()
    private var slots: [DiagnosticEntry?]
    private let capacity: Int
    private var head: Int = 0
    private var size: Int = 0
    private var observers: [UUID: (DiagnosticEntry) -> Void] = [:]

    public init(capacity: Int = EventLog.defaultCapacity) {
        precondition(capacity > 0, "EventLog capacity must be positive")
        self.capacity = capacity
        self.slots = Array(repeating: nil, count: capacity)
    }

    public func append(_ entry: DiagnosticEntry) {
        lock.lock()
        slots[head] = entry
        head = (head + 1) % capacity
        if size < capacity { size += 1 }
        let snapshot = observers.values
        lock.unlock()
        // Fire observers OUTSIDE the lock to prevent callback deadlocks.
        for h in snapshot { h(entry) }
    }

    /// All entries in chronological order (oldest first).
    public func snapshot() -> [DiagnosticEntry] {
        lock.lock()
        defer { lock.unlock() }
        if size == 0 { return [] }
        var result: [DiagnosticEntry] = []
        result.reserveCapacity(size)
        // If size < capacity, head points past the last write; chronological
        // order starts at index 0 and runs to head-1.
        // If size == capacity, head points at the oldest slot (about to be
        // overwritten), so chronological order is [head, head+1, ..., head-1].
        let start = (size < capacity) ? 0 : head
        for i in 0..<size {
            let idx = (start + i) % capacity
            if let e = slots[idx] { result.append(e) }
        }
        return result
    }

    public var count: Int {
        lock.lock(); defer { lock.unlock() }
        return size
    }

    public var maxCapacity: Int { capacity }

    /// Register a callback fired after each successful append. Call
    /// `cancel()` on the returned token to remove. Callback runs on the
    /// thread that called `append`.
    public func onAppend(_ handler: @escaping (DiagnosticEntry) -> Void) -> Cancellable {
        let token = UUID()
        lock.lock()
        observers[token] = handler
        lock.unlock()
        return Cancellable { [weak self] in
            guard let self else { return }
            self.lock.lock()
            self.observers[token] = nil
            self.lock.unlock()
        }
    }
}
