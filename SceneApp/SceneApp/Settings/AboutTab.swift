import SwiftUI

/// "About Scene" tab — version + project link + re-open welcome screen
/// action + V0.6 diagnostic toggle + export.
struct AboutTab: View {
    var reopenWelcome: () -> Void
    var exportDiagnostics: () async -> Void

    @EnvironmentObject var settingsVM: SettingsStoreViewModel

    @State private var exporting = false
    @State private var showDisableConfirm = false

    var body: some View {
        VStack(spacing: 12) {
            Text("about.app_name")
                .font(.largeTitle)
                .bold()
            Text(verbatim: "V\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")")
                .foregroundStyle(.secondary)
            Link(
                "github.com/ChiFungHillmanChan/macbook-resizer",
                destination: URL(string: "https://github.com/ChiFungHillmanChan/macbook-resizer")!
            )

            Divider().padding(.vertical, 8)

            Button(String(localized: "about.welcome.reopen")) {
                reopenWelcome()
            }
            .controlSize(.small)

            Divider().padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 6) {
                Text("about.diagnostics.section.title")
                    .font(.headline)
                Toggle(isOn: Binding(
                    get: { settingsVM.diagnosticsEnabled },
                    set: { newValue in
                        if newValue {
                            Task { await settingsVM.setDiagnosticsEnabled(true) }
                        } else {
                            showDisableConfirm = true
                        }
                    }
                )) {
                    Text("about.diagnostics.toggle")
                }
                Text("about.diagnostics.toggle.help")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    guard !exporting else { return }
                    exporting = true
                    Task {
                        await exportDiagnostics()
                        exporting = false
                    }
                } label: {
                    if exporting {
                        Text("about.diagnostics.export.exporting")
                    } else {
                        Text("about.diagnostics.export.button")
                    }
                }
                .controlSize(.small)
                .disabled(exporting || !settingsVM.diagnosticsEnabled)
                if !settingsVM.diagnosticsEnabled {
                    Text("about.diagnostics.export.disabled.help")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .confirmationDialog(
            String(localized: "about.diagnostics.confirm.disable.title"),
            isPresented: $showDisableConfirm
        ) {
            Button(String(localized: "about.diagnostics.confirm.disable.ok"), role: .destructive) {
                Task { await settingsVM.setDiagnosticsEnabled(false) }
            }
            Button(String(localized: "about.diagnostics.confirm.disable.cancel"), role: .cancel) {}
        } message: {
            Text("about.diagnostics.confirm.disable.body")
        }
    }
}
