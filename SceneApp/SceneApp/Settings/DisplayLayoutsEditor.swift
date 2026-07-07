import SwiftUI
import SceneCore

/// Per-display layout assignment editor. Shows one row per connected display
/// with a layout picker dropdown. Screens not in `displayLayouts` inherit the
/// workspace's primary `layoutID` (shown as "Default"). Preserves entries for
/// disconnected displays so users don't lose config when unplugging a monitor.
struct DisplayLayoutsEditor: View {
    @Binding var displayLayouts: [DisplayLayoutAssignment]
    let fallbackLayoutID: UUID
    @ObservedObject var layoutStore: LayoutStoreViewModel

    private var connectedNames: [String] {
        NSScreen.screens.map { $0.localizedName }
    }

    private var disconnectedEntries: [DisplayLayoutAssignment] {
        let connected = Set(connectedNames)
        return displayLayouts.filter { !connected.contains($0.displayName) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if NSScreen.screens.count <= 1 && displayLayouts.isEmpty {
                Text("workspace.editor.displays.hint")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(connectedNames, id: \.self) { name in
                    displayRow(name: name, disconnected: false)
                }
                ForEach(disconnectedEntries, id: \.displayName) { entry in
                    displayRow(name: entry.displayName, disconnected: true)
                }
            }
        }
    }

    @ViewBuilder
    private func displayRow(name: String, disconnected: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "display")
                        .foregroundStyle(disconnected ? .secondary : .primary)
                    Text(name)
                        .foregroundStyle(disconnected ? .secondary : .primary)
                }
                if disconnected {
                    Text("workspace.editor.displays.disconnected")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Picker("", selection: bindingForDisplay(name)) {
                Text("workspace.editor.displays.default").tag(UUID?.none)
                Divider()
                ForEach(layoutStore.layouts) { layout in
                    Text(layout.name).tag(Optional(layout.id))
                }
            }
            .labelsHidden()
            .frame(maxWidth: 160)
        }
    }

    private func bindingForDisplay(_ name: String) -> Binding<UUID?> {
        Binding(
            get: {
                displayLayouts.first(where: { $0.displayName == name })?.layoutID
            },
            set: { newValue in
                if let layoutID = newValue {
                    if let idx = displayLayouts.firstIndex(where: { $0.displayName == name }) {
                        displayLayouts[idx].layoutID = layoutID
                    } else {
                        displayLayouts.append(DisplayLayoutAssignment(displayName: name, layoutID: layoutID))
                    }
                } else {
                    displayLayouts.removeAll(where: { $0.displayName == name })
                }
            }
        )
    }
}
