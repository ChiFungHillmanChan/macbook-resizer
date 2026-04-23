import SwiftUI
import SceneCore

/// Settings → Workspaces tab. NavigationSplitView with a list of workspaces on
/// the left and the detail editor on the right. Toolbar exposes "+ New",
/// "Duplicate" and "Delete" (V0.5.5 — was previously inline-swipe via
/// `List.onDelete`, but on macOS NavigationSplitView the swipe gesture is
/// barely discoverable, so users believed seeded workspaces couldn't be
/// removed). The `.onDelete` modifier is preserved as a secondary affordance.
///
/// §5 guard: "+ New" is disabled when no layouts exist, and `newWorkspace()`
/// has a defensive `guard let firstLayout` fallback so we never synthesize a
/// dangling `layoutID`.
struct WorkspacesTab: View {
    @ObservedObject var workspaceStore: WorkspaceStoreViewModel
    @ObservedObject var layoutStore: LayoutStoreViewModel
    let calendarPermissionRequester: () async -> Bool
    @State private var selectedID: UUID?
    @State private var errorMessage: String?

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedID) {
                ForEach(workspaceStore.workspaces) { workspace in
                    Row(workspace: workspace, layoutStore: layoutStore)
                        .tag(workspace.id as UUID?)
                }
                .onDelete { indices in
                    for i in indices {
                        let id = workspaceStore.workspaces[i].id
                        do {
                            try workspaceStore.delete(id: id)
                            if selectedID == id { selectedID = nil }
                        } catch {
                            errorMessage = String(describing: error)
                        }
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 240)
            .toolbar {
                ToolbarItemGroup {
                    Button(action: newWorkspace) {
                        Label("workspaces.new", systemImage: "plus")
                    }
                    .disabled(layoutStore.layouts.isEmpty)
                    .help(layoutStore.layouts.isEmpty
                          ? "workspaces.new.disabled.hint"
                          : "workspaces.new")

                    Button(action: duplicateSelected) {
                        Label("workspaces.duplicate", systemImage: "plus.square.on.square")
                    }
                    .disabled(selectedID == nil)

                    Button(action: deleteSelected) {
                        Image(systemName: "trash")
                    }
                    .disabled(selectedID == nil)
                }
            }
        } detail: {
            if let id = selectedID,
               let workspace = workspaceStore.workspaces.first(where: { $0.id == id }) {
                WorkspaceEditorView(
                    workspace: workspace,
                    workspaceStore: workspaceStore,
                    layoutStore: layoutStore,
                    calendarPermissionRequester: calendarPermissionRequester
                )
                .id(workspace.id)  // force re-init when selection changes so @State draft resets
            } else {
                Text("workspaces.detail.empty").foregroundStyle(.secondary)
            }
        }
        .alert("common.error", isPresented: .constant(errorMessage != nil)) {
            Button("common.ok") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func newWorkspace() {
        // §5 guard: never synthesize a random layoutID. Button is disabled when
        // layouts is empty, so this guard is defensive.
        guard let firstLayout = layoutStore.layouts.first else { return }
        let new = Workspace(
            name: String(localized: "workspaces.new.default_name"),
            layoutID: firstLayout.id
        )
        do {
            try workspaceStore.insert(new)
            selectedID = new.id
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func duplicateSelected() {
        guard let id = selectedID else { return }
        do {
            try workspaceStore.duplicate(id: id)
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func deleteSelected() {
        guard let id = selectedID else { return }
        do {
            try workspaceStore.delete(id: id)
            selectedID = nil
        } catch {
            errorMessage = String(describing: error)
        }
    }

    struct Row: View {
        let workspace: Workspace
        @ObservedObject var layoutStore: LayoutStoreViewModel

        var body: some View {
            HStack(spacing: 8) {
                if let layout = layoutStore.layouts.first(where: { $0.id == workspace.layoutID }) {
                    LayoutThumbnail(layout: layout, size: CGSize(width: 32, height: 22))
                } else {
                    Rectangle()
                        .fill(.red.opacity(0.3))
                        .frame(width: 32, height: 22)
                        .overlay(
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                        )
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(workspace.name)
                    if let chord = workspace.hotkey {
                        Text(chord.displayString)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if !workspace.triggers.isEmpty {
                    Image(systemName: "bolt.fill").foregroundStyle(.secondary)
                }
            }
        }
    }
}
