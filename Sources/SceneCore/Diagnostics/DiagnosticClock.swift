import Foundation

/// Time source injected into `DiagnosticWriter`'s rotation logic. Tests
/// use `FakeDiagnosticClock` (in `Tests/SceneCoreTests`) to advance time
/// across midnight without sleeping.
public protocol DiagnosticClock: Sendable {
    func now() -> Date
}

public struct SystemDiagnosticClock: DiagnosticClock {
    public init() {}
    public func now() -> Date { Date() }
}

extension DiagnosticClock {
    /// Day key in the writer's filenames: `events-YYYY-MM-DD.jsonl`.
    /// UTC so a user crossing time zones doesn't suddenly get two files
    /// for the same calendar day on opposite sides of the boundary.
    public func dayString(for date: Date? = nil) -> String {
        let d = date ?? now()
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }
}
