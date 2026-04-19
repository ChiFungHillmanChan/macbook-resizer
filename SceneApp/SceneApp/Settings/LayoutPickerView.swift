import SwiftUI
import SceneCore

/// Horizontal gallery of `LayoutThumbnail`s. Tapping a thumbnail updates the
/// bound `selectedID`. An accent-colored border indicates the active selection.
///
/// If `selectedID` is not present in `layoutStore.layouts` (i.e. the referenced
/// layout was deleted from under us), a red hint row is surfaced. The
/// Workspace editor's Save is still allowed — the red hint only flags the
/// invariant violation; activation-time fallback in `WorkspaceActivator`
/// surfaces a notification before skipping the layout apply step.
struct LayoutPickerView: View {
    @Binding var selectedID: UUID
    @ObservedObject var layoutStore: LayoutStoreViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("workspace.editor.layout").font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(layoutStore.layouts) { layout in
                        VStack(spacing: 4) {
                            LayoutThumbnail(layout: layout, size: CGSize(width: 40, height: 26))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3)
                                        .stroke(
                                            Color.accentColor,
                                            lineWidth: layout.id == selectedID ? 2 : 0
                                        )
                                )
                            Text(layout.name).font(.caption2)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { selectedID = layout.id }
                    }
                }
                .padding(.vertical, 2)
            }
            if !layoutStore.layouts.contains(where: { $0.id == selectedID }) {
                Text("workspace.editor.layout.missing")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }
}
