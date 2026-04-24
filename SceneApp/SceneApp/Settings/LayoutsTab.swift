import SwiftUI
import SceneCore

struct LayoutsTab: View {
    @EnvironmentObject var layoutVM: LayoutStoreViewModel
    @State private var selectedID: UUID?
    @State private var errorMessage: String?

    var body: some View {
        HSplitView {
            List(selection: $selectedID) {
                ForEach(layoutVM.layouts) { layout in
                    HStack {
                        LayoutThumbnail(layout: layout, size: CGSize(width: 32, height: 22))
                            .padding(.trailing, 8)
                        Text(layout.name)
                        if layout.isPresetSeed && layout.isModified {
                            Text("layouts.modified").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let h = layout.hotkey { Text(h.displayString).foregroundStyle(.secondary) }
                    }
                    .tag(layout.id)
                }
            }
            .frame(minWidth: 220)

            detailPane
                .frame(minWidth: 320)
        }
        .toolbar { toolbarContent }
        .alert("common.error", isPresented: .constant(errorMessage != nil)) {
            Button("common.ok") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var detailPane: some View {
        if let id = selectedID,
           let layout = layoutVM.layouts.first(where: { $0.id == id }) {
            LayoutDraftEditor(original: layout, layoutVM: layoutVM)
                .id(layout.id)
        } else {
            Text("layouts.detail.empty")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup {
            Button {
                newLayout()
            } label: { Image(systemName: "plus") }
                .help("layouts.new.template.help")

            // V0.7: a second create-new button that seeds `customTree = .leaf`,
            // routing the new layout into the canvas editor instead of the
            // template editor. The sidebar list and everything downstream
            // (hotkey, store, plan, drag-swap) treats it identically to a
            // template-based layout — only the EDITOR view differs.
            Button {
                newCustomLayout()
            } label: { Image(systemName: "square.on.square.squareshape.controlhandles") }
                .help("layouts.new.custom.help")

            Button {
                deleteSelected()
            } label: { Image(systemName: "trash") }
                .disabled(selectedID == nil)

            Button {
                resetSelectedSeed()
            } label: { Image(systemName: "arrow.counterclockwise") }
                .disabled(!isResettableSeedSelected)

            Button("layouts.restore_defaults") {
                do { try layoutVM.store.restoreDefaultPresets() }
                catch { errorMessage = String(describing: error) }
            }
        }
    }

    private var isResettableSeedSelected: Bool {
        guard let id = selectedID,
              let layout = layoutVM.layouts.first(where: { $0.id == id }) else { return false }
        return layout.isPresetSeed && layout.isModified
    }

    private func newLayout() {
        let new = CustomLayout(
            id: UUID(),
            name: String(localized: "layouts.new.default_name"),
            template: .twoCol,
            slotProportions: LayoutTemplate.twoCol.defaultProportions,
            hotkey: nil,
            isPresetSeed: false,
            isModified: false
        )
        do {
            try layoutVM.store.insert(new)
            selectedID = new.id
        } catch {
            errorMessage = String(describing: error)
        }
    }

    /// V0.7: inserts a new user-authored custom layout with a single-leaf
    /// tree (full-screen slot). The user immediately sees the canvas editor
    /// and can click the leaf to split it into their desired shape.
    /// `template` / `slotProportions` are filled with sentinel values —
    /// `toLayout()` ignores them while `customTree` is non-nil, and the
    /// on-disk JSON decodes cleanly on older binaries (which would just
    /// ignore the unfamiliar `customTree` key).
    private func newCustomLayout() {
        let new = CustomLayout(
            id: UUID(),
            name: String(localized: "layouts.new.custom.default_name"),
            template: .single,
            slotProportions: [],
            hotkey: nil,
            isPresetSeed: false,
            isModified: false,
            customTree: .leaf
        )
        do {
            try layoutVM.store.insert(new)
            selectedID = new.id
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func deleteSelected() {
        guard let id = selectedID else { return }
        do { try layoutVM.store.delete(id: id); selectedID = nil }
        catch { errorMessage = String(describing: error) }
    }

    private func resetSelectedSeed() {
        guard let id = selectedID,
              let layout = layoutVM.layouts.first(where: { $0.id == id }),
              layout.isPresetSeed else { return }
        do { try layoutVM.store.resetSeed(id: id) }
        catch { errorMessage = String(describing: error) }
    }
}

/// Wrapper owning a local `@State draft` copy of the selected layout so edits
/// stay isolated from the store until Save. Paired with `.id(layout.id)` at
/// the call site, which forces reinit on selection change and resets `@State`.
///
/// This mirrors the `WorkspaceEditorView` pattern (@State draft + explicit
/// Save + `.id(...)` on the detail pane). Prior to this wrapper, LayoutsTab
/// bound the editor directly to the store via a computed Binding, so the
/// Save/Cancel buttons were empty stubs and changes streamed into the store
/// on every slider tick — fine until `.onChange(of: draft.template)` in
/// `LayoutEditorView` fired on sidebar selection swap (binding pointed at a
/// different layout, so `draft.template` appeared to change) and silently
/// wrote default proportions back to the destination layout, wiping the
/// user's customizations. Keeping edits in `@State` breaks that reentry
/// because a new wrapper instance owns a fresh `@State`, so `.onChange` only
/// fires for actual user template-picker changes.
private struct LayoutDraftEditor: View {
    @ObservedObject var layoutVM: LayoutStoreViewModel
    @State private var draft: CustomLayout
    /// Snapshot of the draft as of the last successful save (or the initial
    /// load if the user hasn't saved yet). Drives the dirty-state Save button:
    /// when `draft == lastSaved`, there's nothing new to commit, so the Save
    /// button darkens. Any edit diverges draft from lastSaved and re-enables it.
    /// Cancel reverts to this snapshot, not the initial load — so a user who
    /// saves, edits further, then cancels, returns to their saved state instead
    /// of losing everything back to the pristine load.
    @State private var lastSaved: CustomLayout
    @State private var errorMessage: String?

    init(original: CustomLayout, layoutVM: LayoutStoreViewModel) {
        self.layoutVM = layoutVM
        self._draft = State(initialValue: original)
        self._lastSaved = State(initialValue: original)
    }

    private var hasUnsavedChanges: Bool { draft != lastSaved }

    var body: some View {
        Group {
            // V0.7: branch on `customTree`. A non-nil tree means the user
            // created this via the "+ Custom" button and wants the canvas
            // editor. Nil means template-based — fall back to the V0.2 editor.
            if draft.customTree != nil {
                CustomLayoutCanvasEditor(
                    draft: $draft,
                    canSave: hasUnsavedChanges,
                    onSave: save,
                    onCancel: { draft = lastSaved }
                )
            } else {
                LayoutEditorView(
                    draft: $draft,
                    canSave: hasUnsavedChanges,
                    onSave: save,
                    onCancel: { draft = lastSaved }
                )
            }
        }
        .alert("common.error", isPresented: .constant(errorMessage != nil)) {
            Button("common.ok") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func save() {
        do {
            try layoutVM.store.update(draft)
            // Snapshot the just-committed draft so the dirty-state computation
            // sees "nothing to save" and the Save button darkens. Has to happen
            // AFTER the successful store.update so a thrown error (hotkey
            // conflict, etc.) doesn't fool the UI into thinking the save landed.
            lastSaved = draft
        } catch let LayoutStoreError.hotkeyConflict(existingResource) {
            errorMessage = String(format: String(localized: "hotkeys.conflict"), existingResource)
        } catch {
            errorMessage = String(describing: error)
        }
    }
}
