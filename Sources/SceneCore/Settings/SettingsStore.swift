import Foundation

/// Persists user-tunable runtime settings (currently just `AnimationConfig`)
/// as JSON at `fileURL`. First launch seeds the file with `AnimationConfig.default`.
/// Observers registered via `onChange` fire after every successful mutation.
public final class SettingsStore {
    public private(set) var animation: AnimationConfig
    private let fileURL: URL
    private var observers: [UUID: () -> Void] = [:]

    public init(fileURL: URL) throws {
        self.fileURL = fileURL
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode(StoredFile.self, from: data)
            self.animation = decoded.animation
        } else {
            self.animation = .default
            try persist()
        }
    }

    public func setAnimation(_ config: AnimationConfig) throws {
        animation = config
        try persist()
        for h in observers.values { h() }
    }

    public func onChange(_ handler: @escaping () -> Void) -> Cancellable {
        let token = UUID()
        observers[token] = handler
        return Cancellable { [weak self] in self?.observers[token] = nil }
    }

    private func persist() throws {
        let file = StoredFile(version: 1, animation: animation)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(file)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: .atomic)
    }

    private struct StoredFile: Codable {
        let version: Int
        let animation: AnimationConfig
    }
}
