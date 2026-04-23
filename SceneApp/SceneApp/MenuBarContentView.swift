import SwiftUI
import SceneCore

struct MenuBarContentView: View {
    @EnvironmentObject var coordinator: Coordinator
    @EnvironmentObject var appDelegate: AppDelegate
    @EnvironmentObject var updateChecker: UpdateChecker
    @EnvironmentObject var updateInstaller: UpdateInstaller
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

        if let version = updateChecker.availableVersion,
           let releaseURL = updateChecker.releasePageURL {
            Button(action: { handleUpdateClick(version: version, releaseURL: releaseURL) }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(.tint)
                    Text(String(format: String(localized: "menu.update.available"), version))
                        .fontWeight(.semibold)
                }
            }
            Divider()
        }

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

    /// Confirmation flow before kicking off the in-app installer (V0.5.6).
    /// Three-button NSAlert: **Install and Restart** (default), **Release
    /// Notes** (opens GitHub in browser like the pre-V0.5.6 behavior),
    /// **Later** (dismiss). When `dmgURL` is missing — an unusual GitHub
    /// release with no `.dmg` asset — we silently fall back to opening the
    /// release page so the user can still find the install path.
    private func handleUpdateClick(version: String, releaseURL: URL) {
        guard let dmgURL = updateChecker.dmgURL else {
            NSWorkspace.shared.open(releaseURL)
            return
        }
        let alert = NSAlert()
        alert.messageText = String(
            format: String(localized: "update.install.alert.title"),
            version
        )
        alert.informativeText = String(localized: "update.install.alert.body")
        alert.alertStyle = .informational
        alert.addButton(withTitle: String(localized: "update.install.alert.install_and_restart"))
        alert.addButton(withTitle: String(localized: "update.install.alert.release_notes"))
        alert.addButton(withTitle: String(localized: "update.install.alert.later"))
        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            Task { @MainActor in
                await updateInstaller.install(dmgURL: dmgURL, version: version)
            }
        case .alertSecondButtonReturn:
            NSWorkspace.shared.open(releaseURL)
        default:
            break
        }
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
