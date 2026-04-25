import Foundation

/// Persists user-tunable runtime settings (`AnimationConfig`, `DragSwapConfig`)
/// as JSON at `fileURL`. First launch seeds defaults. Loading a v1 file (V0.2
/// shape, no `dragSwap` field) auto-migrates to v2 with `DragSwapConfig.default`
/// and atomically rewrites the file. Observers registered via `onChange` fire
/// after every successful mutation.
public final class SettingsStore {
    public private(set) var animation: AnimationConfig
    public private(set) var dragSwap: DragSwapConfig
    /// V0.6 diagnostic-logging master switch. Default `true` so users
    /// who upgrade silently keep diagnostic coverage; the AboutTab
    /// toggle lets them opt out (which drains the writer + deletes the
    /// `diagnostics/` directory).
    public private(set) var diagnosticsEnabled: Bool
    private let fileURL: URL
    private var observers: [UUID: () -> Void] = [:]

    public static let currentVersion = 3

    public init(fileURL: URL) throws {
        self.fileURL = fileURL
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let data = try Data(contentsOf: fileURL)
            let (animation, dragSwap, diagnosticsEnabled, needsRewrite) = try Self.decodeWithMigration(data: data)
            self.animation = animation
            self.dragSwap = dragSwap
            self.diagnosticsEnabled = diagnosticsEnabled
            if needsRewrite { try persist() }
        } else {
            self.animation = .default
            self.dragSwap = .default
            self.diagnosticsEnabled = true
            try persist()
        }
    }

    public func setAnimation(_ config: AnimationConfig) throws {
        animation = config
        try persist()
        for h in observers.values { h() }
    }

    public func setDragSwap(_ config: DragSwapConfig) throws {
        dragSwap = config
        try persist()
        for h in observers.values { h() }
    }

    public func setDiagnosticsEnabled(_ value: Bool) throws {
        diagnosticsEnabled = value
        try persist()
        for h in observers.values { h() }
    }

    public func onChange(_ handler: @escaping () -> Void) -> Cancellable {
        let token = UUID()
        observers[token] = handler
        return Cancellable { [weak self] in self?.observers[token] = nil }
    }

    private func persist() throws {
        let file = StoredFile(
            version: Self.currentVersion,
            animation: animation,
            dragSwap: dragSwap,
            diagnosticsEnabled: diagnosticsEnabled
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(file)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: .atomic)
    }

    /// Decodes whatever schema version is on disk; returns `needsRewrite=true`
    /// if the file must be upgraded and persisted back.
    private static func decodeWithMigration(data: Data) throws -> (AnimationConfig, DragSwapConfig, Bool, Bool) {
        let versionProbe = try JSONDecoder().decode(VersionProbe.self, from: data)
        switch versionProbe.version {
        case 3:
            let v3 = try JSONDecoder().decode(StoredFile.self, from: data)
            return (v3.animation, v3.dragSwap, v3.diagnosticsEnabled, false)
        case 2:
            let v2 = try JSONDecoder().decode(StoredFileV2.self, from: data)
            // Default V0.6 diagnostics ON for upgraded users — they can
            // still opt out via the AboutTab toggle.
            return (v2.animation, v2.dragSwap, true, true)
        case 1:
            let v1 = try JSONDecoder().decode(StoredFileV1.self, from: data)
            return (v1.animation, .default, true, true)
        default:
            throw DecodingError.dataCorrupted(.init(
                codingPath: [],
                debugDescription: "Unsupported settings schema version \(versionProbe.version)"
            ))
        }
    }

    private struct VersionProbe: Codable { let version: Int }

    private struct StoredFile: Codable {
        let version: Int
        let animation: AnimationConfig
        let dragSwap: DragSwapConfig
        let diagnosticsEnabled: Bool
    }

    private struct StoredFileV2: Codable {
        let version: Int
        let animation: AnimationConfig
        let dragSwap: DragSwapConfig
    }

    private struct StoredFileV1: Codable {
        let version: Int
        let animation: AnimationConfig
    }
}
