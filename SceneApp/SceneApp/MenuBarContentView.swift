import SwiftUI
import SceneCore

struct MenuBarContentView: View {
    @EnvironmentObject var coordinator: Coordinator
    @EnvironmentObject var appDelegate: AppDelegate
    @ObservedObject var workspaceStore: WorkspaceStoreViewModel
    @ObservedObject var layoutStore: LayoutStoreViewModel

    var body: some View {
        if coordinator.permissionGranted {
            grantedMenu
        } else {
            ungrantedMenu
        }
    }

    @ViewBuilder
    private var grantedMenu: some View {
        // Touch layoutListVersion so SwiftUI rebuilds when LayoutStore mutates.
        let _ = coordinator.layoutListVersion

        // MARK: - Workspaces (V0.4)

        Section(header: Text("menu.section.workspaces")
            .font(.caption)
            .foregroundStyle(.secondary)
        ) {
            if workspaceStore.workspaces.isEmpty {
                Text("menu.workspaces.empty")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 4)
            } else {
                ForEach(workspaceStore.workspaces) { workspace in
                    Button(action: { activate(workspace: workspace) }) {
                        HStack(spacing: 6) {
                            if workspaceStore.activeWorkspaceID == workspace.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            } else {
                                Spacer().frame(width: 14)
                            }
                            if let layout = layoutStore.layouts.first(where: { $0.id == workspace.layoutID }) {
                                LayoutThumbnail(layout: layout, size: CGSize(width: 24, height: 16))
                            } else {
                                Rectangle()
                                    .fill(.red.opacity(0.3))
                                    .frame(width: 24, height: 16)
                            }
                            Text(workspace.name)
                                .fontWeight(
                                    workspaceStore.activeWorkspaceID == workspace.id ? .semibold : .regular
                                )
                            Spacer()
                            if let chord = workspace.hotkey {
                                Text(chord.displayString)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }

        Divider()

        // MARK: - Layouts

        ForEach(layoutStore.layouts) { layout in
            Button {
                coordinator.applyLayout(layout)
            } label: {
                HStack {
                    LayoutThumbnail(layout: layout, size: CGSize(width: 24, height: 16))
                        .padding(.trailing, 6)
                    Text(label(for: layout))
                }
            }
        }

        Divider()
        Button("menu.settings") {
            appDelegate.openSettings()
        }
        .keyboardShortcut(",")
        Divider()
        Button("menu.quit") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    @ViewBuilder
    private var ungrantedMenu: some View {
        Button("menu.grant_accessibility") {
            coordinator.openOnboarding()
        }
        Divider()
        Button("menu.quit") { NSApp.terminate(nil) }
    }

    private func activate(workspace: Workspace) {
        let id = workspace.id
        Task { @MainActor in
            await coordinator.applyWorkspace(id: id)
        }
    }

    private func label(for layout: CustomLayout) -> String {
        if let h = layout.hotkey {
            return "\(layout.name)\t\(h.displayString)"
        }
        return layout.name
    }
}
