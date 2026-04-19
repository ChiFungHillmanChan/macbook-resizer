import Combine
import Foundation
import SceneCore
import class SceneCore.Cancellable

/// SwiftUI-friendly adapter around `WorkspaceStore`.
///
/// Mirrors `LayoutStoreViewModel`'s pattern: re-publishes the store's list via
/// `@Published` and observes store changes through the closure-based token that
/// `WorkspaceStore.onChange(_:)` returns. The adapter hops to `@MainActor`
/// before mutating `@Published` state so SwiftUI diffs happen on the main
/// thread regardless of which thread the underlying store mutates on.
@MainActor
final class WorkspaceStoreViewModel: ObservableObject {
    let store: WorkspaceStore
    @Published private(set) var workspaces: [Workspace] = []
    @Published private(set) var activeWorkspaceID: UUID? = nil

    private var token: Cancellable?

    init(store: WorkspaceStore) {
        self.store = store
        self.workspaces = store.workspaces
        self.activeWorkspaceID = store.activeWorkspaceID
        let weakSelf = WeakBox(self)
        self.token = store.onChange {
            Task { @MainActor in
                guard let strong = weakSelf.value else { return }
                strong.resync()
            }
        }
    }

    private func resync() {
        self.workspaces = store.workspaces
        self.activeWorkspaceID = store.activeWorkspaceID
    }

    func update(_ workspace: Workspace) throws { try store.update(workspace) }
    func insert(_ workspace: Workspace) throws { try store.insert(workspace) }
    func delete(id: UUID) throws { try store.delete(id: id) }

    /// Duplicate-with-fresh-UUID helper. Clears hotkey and triggers so the new
    /// Workspace never collides with its source on the first save.
    func duplicate(id: UUID) throws {
        guard let source = store.workspaces.first(where: { $0.id == id }) else { return }
        let duplicate = Workspace(
            id: UUID(),
            name: source.name + " Copy",
            layoutID: source.layoutID,
            appsToLaunch: source.appsToLaunch,
            appsToQuit: source.appsToQuit,
            focusMode: source.focusMode,
            hotkey: nil,
            triggers: [],
            isPresetSeed: false,
            isModified: false
        )
        try store.insert(duplicate)
    }
}

private final class WeakBox<T: AnyObject> {
    weak var value: T?
    init(_ value: T) { self.value = value }
}
