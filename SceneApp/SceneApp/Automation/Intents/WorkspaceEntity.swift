import AppIntents
import AppKit
import SceneCore

struct WorkspaceEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Workspace"
    static var defaultQuery = WorkspaceEntityQuery()

    let id: UUID
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct WorkspaceEntityQuery: EntityQuery {
    @MainActor
    private var store: WorkspaceStore? {
        (NSApp.delegate as? AppDelegate)?.workspaceStore
    }

    @MainActor
    func entities(for ids: [UUID]) async throws -> [WorkspaceEntity] {
        guard let store else { return [] }
        return store.workspaces
            .filter { ids.contains($0.id) }
            .map { WorkspaceEntity(id: $0.id, name: $0.name) }
    }

    @MainActor
    func suggestedEntities() async throws -> [WorkspaceEntity] {
        guard let store else { return [] }
        return store.workspaces.map { WorkspaceEntity(id: $0.id, name: $0.name) }
    }
}
