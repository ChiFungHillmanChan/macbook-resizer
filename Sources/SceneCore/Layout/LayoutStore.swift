import Foundation

/// Errors thrown by `LayoutStore` mutating APIs.
public enum LayoutStoreError: Error, Equatable {
    case duplicateID
    case notFound
    case notASeed
    /// Raised when an `insert` or `update` would assign a hotkey already owned
    /// by another layout or by an external resource (e.g., a Workspace, see
    /// `setHotkeyConflictProbe`). `existingResource` is the owning resource's
    /// display name (layout name or workspace name) so callers can surface a
    /// "Used by …" message in the UI.
    case hotkeyConflict(existingResource: String)
}

/// Persists the user's `CustomLayout` collection as JSON.
///
/// First launch seeds the file with `PresetSeeds.all` and records each preset's
/// UUID under `knownSeedUUIDs`. On subsequent launches the file is loaded as-is
/// and never re-seeded, so deleting a preset stays deleted across restarts.
///
/// V0.3+ presets can be introduced via `applyFutureSeeds(candidates:)`, which
/// only inserts ids not already in `knownSeedUUIDs` (preventing previously
/// deleted presets from coming back).
///
/// All mutating APIs persist atomically and notify observers registered via
/// `onChange`.
public final class LayoutStore {
    public private(set) var layouts: [CustomLayout]
    private(set) var knownSeedUUIDs: Set<UUID>
    private let fileURL: URL
    private var observers: [UUID: () -> Void] = [:]
    /// V0.4 cross-store hotkey conflict probe. Returns the display name of an
    /// external resource (typically a Workspace) that owns the given chord,
    /// or nil if no external conflict. AppDelegate installs the real probe
    /// via `setHotkeyConflictProbe(_:)` after both stores are constructed
    /// (Cross-cutting conventions §3).
    private var hotkeyConflictProbe: (HotkeyBinding) -> String? = { _ in nil }

    public init(fileURL: URL) throws {
        self.fileURL = fileURL
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode(StoredFile.self, from: data)
            self.layouts = decoded.layouts
            self.knownSeedUUIDs = Set(decoded.knownSeedUUIDs)
        } else {
            self.layouts = PresetSeeds.all
            self.knownSeedUUIDs = PresetSeeds.allUUIDs
            try persist()
        }
    }

    // MARK: - CRUD

    public func insert(_ layout: CustomLayout) throws {
        guard !layouts.contains(where: { $0.id == layout.id }) else {
            throw LayoutStoreError.duplicateID
        }
        try assertNoHotkeyConflict(for: layout)
        layouts.append(layout)
        try persist()
        notify()
    }

    public func update(_ layout: CustomLayout) throws {
        guard let idx = layouts.firstIndex(where: { $0.id == layout.id }) else {
            throw LayoutStoreError.notFound
        }
        try assertNoHotkeyConflict(for: layout)

        var next = layout
        if next.isPresetSeed,
           let original = PresetSeeds.all.first(where: { $0.id == layout.id }) {
            let drift =
                next.name != original.name
                || next.template != original.template
                || next.slotProportions != original.slotProportions
            next.isModified = drift
            next.isPresetSeed = true
        }
        layouts[idx] = next
        try persist()
        notify()
    }

    public func delete(id: UUID) throws {
        guard let idx = layouts.firstIndex(where: { $0.id == id }) else {
            throw LayoutStoreError.notFound
        }
        layouts.remove(at: idx)
        try persist()
        notify()
    }

    // MARK: - Seed management

    /// Re-inserts any `PresetSeeds.all` entries that are not currently present.
    /// Idempotent. Notifies observers only when something actually changed.
    public func restoreDefaultPresets() throws {
        var changed = false
        for seed in PresetSeeds.all where !layouts.contains(where: { $0.id == seed.id }) {
            layouts.append(seed)
            knownSeedUUIDs.insert(seed.id)
            changed = true
        }
        if changed {
            try persist()
            notify()
        }
    }

    /// Resets a preset seed's name/template/proportions to its compiled-in default.
    /// Per spec §3.6, the user's hotkey assignment is intentionally preserved.
    public func resetSeed(id: UUID) throws {
        guard let original = PresetSeeds.all.first(where: { $0.id == id }) else {
            throw LayoutStoreError.notASeed
        }
        guard let idx = layouts.firstIndex(where: { $0.id == id }) else {
            throw LayoutStoreError.notFound
        }
        var current = layouts[idx]
        current.name = original.name
        current.template = original.template
        current.slotProportions = original.slotProportions
        current.isPresetSeed = true
        current.isModified = false
        // hotkey intentionally preserved
        layouts[idx] = current
        try persist()
        notify()
    }

    /// Adds candidates whose ids are NOT already in `knownSeedUUIDs`. This is
    /// the upgrade path for V0.3+ presets — any candidate whose id was already
    /// known (and presumably later deleted by the user) is skipped.
    public func applyFutureSeeds(candidates: [CustomLayout]) throws {
        var changed = false
        for candidate in candidates where !knownSeedUUIDs.contains(candidate.id) {
            knownSeedUUIDs.insert(candidate.id)
            if !layouts.contains(where: { $0.id == candidate.id }) {
                layouts.append(candidate)
            }
            changed = true
        }
        if changed {
            try persist()
            notify()
        }
    }

    // MARK: - Observation

    public func onChange(_ handler: @escaping () -> Void) -> Cancellable {
        let token = UUID()
        observers[token] = handler
        return Cancellable { [weak self] in self?.observers[token] = nil }
    }

    // MARK: - Internals

    /// Throws `.hotkeyConflict(existingResource:)` if `candidate.hotkey` is
    /// owned by another layout (internal) or by an external resource — typically
    /// a Workspace — as reported by `hotkeyConflictProbe`.
    private func assertNoHotkeyConflict(for candidate: CustomLayout) throws {
        guard let chord = candidate.hotkey else { return }
        for other in layouts where other.id != candidate.id {
            if let otherChord = other.hotkey, otherChord.conflicts(with: chord) {
                throw LayoutStoreError.hotkeyConflict(existingResource: other.name)
            }
        }
        if let external = hotkeyConflictProbe(chord) {
            throw LayoutStoreError.hotkeyConflict(existingResource: external)
        }
    }

    // MARK: - Cross-store probe

    /// Install a probe that returns the display name of a Workspace (or other
    /// external resource) that owns a given hotkey chord. Scene's AppDelegate
    /// installs this AFTER both LayoutStore and WorkspaceStore are constructed,
    /// resolving the circular-dependency bootstrap (see Cross-cutting conventions §3).
    /// Call with `{ _ in nil }` to disable.
    public func setHotkeyConflictProbe(_ probe: @escaping (HotkeyBinding) -> String?) {
        self.hotkeyConflictProbe = probe
    }

    private func notify() {
        for h in observers.values { h() }
    }

    private func persist() throws {
        let file = StoredFile(
            version: 1,
            knownSeedUUIDs: Array(knownSeedUUIDs),
            layouts: layouts
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

    private struct StoredFile: Codable {
        let version: Int
        let knownSeedUUIDs: [UUID]
        let layouts: [CustomLayout]
    }
}
