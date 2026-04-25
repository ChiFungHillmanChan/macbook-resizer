import Foundation

/// 32 random bytes persisted at `<dir>/.salt` with file mode `0600`.
///
/// Salt **never** leaves the user's machine — it is loaded into RAM by
/// `DiagnosticWriter` at startup and used for in-process hashing of
/// user-authored strings (workspace names, bundle IDs, etc.). The export
/// bundle contains only `hashID = SHA256(salt)[0:8]`, which lets devs
/// confirm "every hash in this bundle shares one family" without
/// recovering the salt itself.
public struct SaltStore {
    public let url: URL
    public static let saltByteCount = 32

    public init(directory: URL) {
        self.url = directory.appendingPathComponent(".salt")
    }

    /// Returns the existing salt, or generates a fresh one if missing.
    /// Always sets file mode to `0600` after write.
    public func loadOrCreate() throws -> Data {
        let fm = FileManager.default
        if fm.fileExists(atPath: url.path) {
            let data = try Data(contentsOf: url)
            if data.count == Self.saltByteCount {
                try Self.enforcePermissions(at: url)
                return data
            }
            // Corrupt or wrong size — regenerate
        }
        return try regenerate()
    }

    /// Forces a brand new salt. Used when the user toggles diagnostics
    /// OFF → ON to break correlation across enable-periods.
    @discardableResult
    public func regenerate() throws -> Data {
        let fm = FileManager.default
        try fm.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        var bytes = [UInt8](repeating: 0, count: Self.saltByteCount)
        for i in 0..<bytes.count { bytes[i] = UInt8.random(in: 0...255) }
        let data = Data(bytes)
        try data.write(to: url, options: .atomic)
        try Self.enforcePermissions(at: url)
        return data
    }

    public func delete() throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: url.path) {
            try fm.removeItem(at: url)
        }
    }

    private static func enforcePermissions(at url: URL) throws {
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600 as NSNumber],
            ofItemAtPath: url.path
        )
    }
}
