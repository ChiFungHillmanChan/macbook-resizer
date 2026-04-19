import Foundation

public enum WorkspaceStoreError: Error, Equatable {
    /// Thrown when a Workspace hotkey collides with another Workspace or Layout.
    /// `existingResource` is the display name of the owning layout or workspace.
    case hotkeyConflict(existingResource: String)
    /// Thrown by `update(_:)` when no workspace exists with the given ID.
    /// Callers that want upsert semantics should call `insert(_:)` instead.
    case notFound(id: UUID)
    case decodingFailed(String)
}

/// Persists and observes Workspaces in `~/Library/Application Support/Scene/workspaces.json`.
/// Mirrors `LayoutStore`'s closure-observation + atomic-write + knownSeedUUIDs pattern.
///
/// Cross-store hotkey conflict: `hotkeyConflictProbe` is supplied by the caller
/// and returns the display name of an external resource (typically a Layout)
/// that owns a given chord, or `nil` if the chord is free externally. See
/// Cross-cutting conventions §3 — the canonical wire-up path is
/// `setHotkeyConflictProbe(_:)` after both stores are constructed; the init
/// parameter defaults to a no-op probe for single-test convenience.
public final class WorkspaceStore {
    private struct DiskModel: Codable {
        var version: Int
        var knownSeedUUIDs: [UUID]
        var activeWorkspaceID: UUID?
        var workspaces: [Workspace]
    }

    public private(set) var workspaces: [Workspace]
    public private(set) var activeWorkspaceID: UUID?
    public private(set) var knownSeedUUIDs: Set<UUID>

    private let fileURL: URL
    private var hotkeyConflictProbe: (HotkeyBinding) -> String?
    private var observers: [UUID: () -> Void] = [:]

    public init(
        fileURL: URL,
        hotkeyConflictProbe: @escaping (HotkeyBinding) -> String? = { _ in nil }
    ) throws {
        self.fileURL = fileURL
        self.hotkeyConflictProbe = hotkeyConflictProbe

        if FileManager.default.fileExists(atPath: fileURL.path) {
            let data = try Data(contentsOf: fileURL)
            let model = try JSONDecoder().decode(DiskModel.self, from: data)
            self.workspaces = model.workspaces
            self.activeWorkspaceID = model.activeWorkspaceID
            self.knownSeedUUIDs = Set(model.knownSeedUUIDs)
        } else {
            self.workspaces = WorkspaceSeeds.all
            self.activeWorkspaceID = nil
            self.knownSeedUUIDs = Set(WorkspaceSeeds.all.map { $0.id })
            try persist()
        }
    }

    // MARK: - CRUD

    public func update(_ workspace: Workspace) throws {
        try assertNoHotkeyConflict(workspace)
        guard let idx = workspaces.firstIndex(where: { $0.id == workspace.id }) else {
            // Strict update semantics — see Cross-cutting conventions §4.
            // Callers that want upsert call `insert(_:)` separately.
            throw WorkspaceStoreError.notFound(id: workspace.id)
        }
        var updated = workspace
        if updated.isPresetSeed {
            updated.isModified = !isSemanticallyEqualToSeed(workspace: updated) || updated.isModified
        }
        workspaces[idx] = updated
        try persist()
        notify()
    }

    public func insert(_ workspace: Workspace) throws {
        try assertNoHotkeyConflict(workspace)
        workspaces.append(workspace)
        try persist()
        notify()
    }

    public func delete(id: UUID) throws {
        workspaces.removeAll { $0.id == id }
        if activeWorkspaceID == id { activeWorkspaceID = nil }
        try persist()
        notify()
    }

    public func setActive(_ id: UUID?) throws {
        activeWorkspaceID = id
        try persist()
        notify()
    }

    public func applyFutureSeeds(_ futureSeeds: [Workspace]) throws {
        var changed = false
        for seed in futureSeeds where !knownSeedUUIDs.contains(seed.id) {
            workspaces.append(seed)
            knownSeedUUIDs.insert(seed.id)
            changed = true
        }
        if changed {
            try persist()
            notify()
        }
    }

    /// Install / replace the cross-store conflict probe. See Cross-cutting conventions §3.
    /// Pass `{ _ in nil }` to disable.
    public func setHotkeyConflictProbe(_ probe: @escaping (HotkeyBinding) -> String?) {
        self.hotkeyConflictProbe = probe
    }

    // MARK: - Observation

    public func onChange(_ handler: @escaping () -> Void) -> Cancellable {
        let token = UUID()
        observers[token] = handler
        return Cancellable { [weak self] in
            self?.observers.removeValue(forKey: token)
        }
    }

    // MARK: - Private

    private func assertNoHotkeyConflict(_ workspace: Workspace) throws {
        guard let chord = workspace.hotkey else { return }
        // Internal conflict: another Workspace owns this chord.
        if let other = workspaces.first(where: { $0.id != workspace.id && $0.hotkey == chord }) {
            throw WorkspaceStoreError.hotkeyConflict(existingResource: other.name)
        }
        // External conflict: a Layout owns this chord.
        if let layoutName = hotkeyConflictProbe(chord) {
            throw WorkspaceStoreError.hotkeyConflict(existingResource: layoutName)
        }
    }

    private func isSemanticallyEqualToSeed(workspace: Workspace) -> Bool {
        guard let seed = WorkspaceSeeds.all.first(where: { $0.id == workspace.id }) else { return false }
        return seed.name == workspace.name &&
               seed.layoutID == workspace.layoutID &&
               seed.appsToLaunch == workspace.appsToLaunch &&
               seed.appsToQuit == workspace.appsToQuit &&
               seed.focusMode == workspace.focusMode &&
               seed.hotkey == workspace.hotkey &&
               seed.triggers == workspace.triggers
    }

    private func persist() throws {
        let model = DiskModel(
            version: 1,
            knownSeedUUIDs: Array(knownSeedUUIDs),
            activeWorkspaceID: activeWorkspaceID,
            workspaces: workspaces
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(model)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: .atomic)
    }

    private func notify() {
        observers.values.forEach { $0() }
    }
}
