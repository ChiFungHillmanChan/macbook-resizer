import AppIntents
import AppKit
import SceneCore

/// Wraps a Scene custom layout so AppIntents can prompt for one in
/// Shortcuts.app and pass it through `ApplyLayoutIntent`.
struct LayoutEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Layout"
    static var defaultQuery = LayoutEntityQuery()

    let id: UUID
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct LayoutEntityQuery: EntityQuery {
    @MainActor
    private var store: LayoutStore? {
        (NSApp.delegate as? AppDelegate)?.layoutStore
    }

    @MainActor
    func entities(for ids: [UUID]) async throws -> [LayoutEntity] {
        guard let store else { return [] }
        return store.layouts
            .filter { ids.contains($0.id) }
            .map { LayoutEntity(id: $0.id, name: $0.name) }
    }

    @MainActor
    func suggestedEntities() async throws -> [LayoutEntity] {
        guard let store else { return [] }
        return store.layouts.map { LayoutEntity(id: $0.id, name: $0.name) }
    }
}
