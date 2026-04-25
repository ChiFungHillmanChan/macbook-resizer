import Foundation

/// Pure file-size enforcement helpers used by `DiagnosticWriter`. All
/// state is on disk; these functions are stateless modulo the
/// `FileManager` they touch.
public enum DiagnosticBudget {
    public static let activeFileMaxBytes = 100_000   // 100 KB hard ceiling per active day file
    public static let totalBudgetBytes   = 2_000_000 // 2 MB across all .jsonl + .jsonl.gz
    public static let retentionDays      = 7

    public static let filenamePrefix = "events-"
    public static let activeExtension = "jsonl"
    public static let rotatedExtension = "jsonl.gz"

    // MARK: - Newline-aware truncation

    /// Truncate `url` to at most `keepLastBytes` bytes, dropping through
    /// the first newline AT or AFTER the new start to ensure the
    /// resulting file begins on a complete JSON line. If the tail
    /// contains no newline, the file is emptied (only one partial
    /// record was present and we'd rather drop it than leave broken
    /// JSON).
    public static func truncateActiveFile(at url: URL, keepLastBytes: Int) throws {
        let data = try Data(contentsOf: url)
        guard data.count > keepLastBytes else { return }
        let tailStart = data.count - keepLastBytes
        let tail = data[tailStart...]
        guard let firstLF = tail.firstIndex(of: 0x0A) else {
            try Data().write(to: url, options: .atomic)
            return
        }
        // firstLF is an index into `data`; the kept payload starts AFTER it.
        let cutoff = firstLF + 1
        let kept = data[cutoff...]
        try Data(kept).write(to: url, options: .atomic)
    }

    // MARK: - Compression on rotation

    /// Compresses `url` to `<url>.gz`, then removes the original. If
    /// either step fails, leaves the directory in its prior state.
    public static func compressFile(at url: URL) throws {
        let gzURL = URL(fileURLWithPath: url.path + ".gz")
        let raw = try Data(contentsOf: url)
        let gz = try GzipWriter.compress(raw)
        try gz.write(to: gzURL, options: .atomic)
        try FileManager.default.removeItem(at: url)
    }

    // MARK: - Retention

    /// Remove every `events-YYYY-MM-DD.jsonl[.gz]` whose embedded day is
    /// strictly older than `now - days`. Active day's file is preserved
    /// even if days==0 (callers responsible for not stomping themselves).
    public static func removeOlderThan(
        directory: URL,
        days: Int,
        now: Date,
        formatter: DateFormatter = Self.dayFormatter
    ) throws {
        let cutoff = now.addingTimeInterval(-Double(days) * 86_400)
        let cutoffDay = formatter.string(from: cutoff)
        let entries = try diagnosticFiles(in: directory)
        for e in entries where e.day < cutoffDay {
            try? FileManager.default.removeItem(at: e.url)
        }
    }

    // MARK: - Total budget

    /// While the total size of `events-*` files exceeds `budgetBytes`,
    /// delete the oldest **rotated** file. The currently active
    /// `.jsonl` (if any) is preserved — the caller's writer is using it.
    public static func applyTotalBudget(
        directory: URL,
        budgetBytes: Int = Self.totalBudgetBytes
    ) throws {
        var entries = try diagnosticFiles(in: directory)
        // Sort oldest-first so the front of the list is the first to evict.
        entries.sort { $0.day < $1.day }
        var total = entries.reduce(0) { $0 + $1.size }
        var idx = 0
        while total > budgetBytes && idx < entries.count {
            let e = entries[idx]
            if e.isRotated {
                try? FileManager.default.removeItem(at: e.url)
                total -= e.size
            }
            idx += 1
        }
    }

    // MARK: - Filesystem listing

    public struct DiagnosticFile: Equatable {
        public let url: URL
        public let day: String      // "2026-04-25"
        public let isRotated: Bool  // .jsonl.gz vs .jsonl
        public let size: Int
    }

    public static func diagnosticFiles(in directory: URL) throws -> [DiagnosticFile] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: directory.path) else { return [] }
        let urls = try fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        )
        var result: [DiagnosticFile] = []
        for url in urls {
            let name = url.lastPathComponent
            guard let day = parseDay(fromName: name) else { continue }
            let isRot = name.hasSuffix(".\(rotatedExtension)")
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            result.append(.init(url: url, day: day, isRotated: isRot, size: size))
        }
        return result
    }

    /// Extract the `YYYY-MM-DD` portion from `events-YYYY-MM-DD.jsonl[.gz]`,
    /// or nil for unrelated files.
    public static func parseDay(fromName name: String) -> String? {
        guard name.hasPrefix(filenamePrefix) else { return nil }
        let after = name.dropFirst(filenamePrefix.count)
        guard after.count >= 10 else { return nil }
        let day = String(after.prefix(10))
        // Cheap shape check: YYYY-MM-DD
        let parts = day.split(separator: "-")
        guard parts.count == 3,
              parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              parts.allSatisfy({ $0.allSatisfy(\.isNumber) })
        else { return nil }
        // Must end with one of our extensions
        let rest = after.dropFirst(10)
        return (rest == ".\(activeExtension)" || rest == ".\(rotatedExtension)") ? day : nil
    }

    public static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
