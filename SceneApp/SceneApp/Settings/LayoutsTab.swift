import SwiftUI
import SceneCore

struct LayoutsTab: View {
    @EnvironmentObject var layoutVM: LayoutStoreViewModel
    @State private var selectedID: UUID?
    @State private var draft: CustomLayout?
    @State private var errorMessage: String?

    var body: some View {
        HSplitView {
            List(selection: $selectedID) {
                ForEach(layoutVM.layouts) { layout in
                    HStack {
                        Text(layout.name)
                        if layout.isPresetSeed && layout.isModified {
                            Text("(modified)").font(.caption).foregroundStyle(.secondary)
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
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var detailPane: some View {
        if let d = draft {
            LayoutEditorView(
                draft: Binding(
                    get: { d },
                    set: { newValue in self.draft = newValue }
                ),
                onSave: { saveDraft() },
                onCancel: { self.draft = nil }
            )
        } else if let id = selectedID, let layout = layoutVM.layouts.first(where: { $0.id == id }) {
            LayoutEditorView(
                draft: Binding(
                    get: { layout },
                    set: { newValue in
                        do { try layoutVM.store.update(newValue) }
                        catch { errorMessage = String(describing: error) }
                    }
                ),
                onSave: {},
                onCancel: {}
            )
        } else {
            Text("Select a layout or create a new one")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup {
            Button {
                draft = CustomLayout(
                    id: UUID(),
                    name: "New Layout",
                    template: .twoCol,
                    slotProportions: LayoutTemplate.twoCol.defaultProportions,
                    hotkey: nil,
                    isPresetSeed: false,
                    isModified: false
                )
            } label: { Image(systemName: "plus") }

            Button {
                guard let id = selectedID else { return }
                do { try layoutVM.store.delete(id: id); selectedID = nil }
                catch { errorMessage = String(describing: error) }
            } label: { Image(systemName: "trash") }
                .disabled(selectedID == nil)

            Button {
                guard let id = selectedID,
                      let layout = layoutVM.layouts.first(where: { $0.id == id }),
                      layout.isPresetSeed else { return }
                do { try layoutVM.store.resetSeed(id: id) }
                catch { errorMessage = String(describing: error) }
            } label: { Image(systemName: "arrow.counterclockwise") }
                .disabled(!isResettableSeedSelected)

            Button("Restore Default Presets") {
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

    private func saveDraft() {
        guard let d = draft else { return }
        do {
            try layoutVM.store.insert(d)
            selectedID = d.id
            draft = nil
        } catch {
            errorMessage = String(describing: error)
        }
    }
}
