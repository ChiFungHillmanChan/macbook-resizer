import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Bundle-ID list editor used twice in the Workspace editor (apps-to-launch and
/// apps-to-quit). Adds apps via either NSOpenPanel (primary) or Finder
/// drag-drop (`.fileURL` provider). Stored bundle IDs are deduped so the same
/// app cannot be added twice.
///
/// Icon and display name are resolved on-the-fly from `NSWorkspace`; if the
/// app is not installed, we show the raw bundle ID and no icon — the
/// Workspace is still valid and will simply no-op that bundle at activate
/// time.
struct AppPickerView: View {
    @Binding var bundleIDs: [String]
    let label: LocalizedStringKey
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.headline)
            HStack {
                Spacer()
                Button("workspace.editor.apps.add") {
                    addViaPanel()
                }
            }
            List {
                ForEach(bundleIDs, id: \.self) { id in
                    HStack {
                        if let icon = appIcon(for: id) {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 16, height: 16)
                        } else {
                            Image(systemName: "app.dashed")
                                .frame(width: 16, height: 16)
                                .foregroundStyle(.secondary)
                        }
                        Text(appName(for: id) ?? id)
                        Spacer()
                        Button(action: { bundleIDs.removeAll { $0 == id } }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("workspace.editor.apps.remove")
                    }
                }
            }
            .frame(minHeight: 80, maxHeight: 140)
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                handleDrop(providers: providers)
            }
            if let err = errorMessage {
                Text(err).font(.caption).foregroundStyle(.red)
            }
        }
    }

    // MARK: - Actions

    private func addViaPanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.application]
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            add(url: url)
        }
    }

    @discardableResult
    private func add(url: URL) -> Bool {
        guard url.pathExtension.lowercased() == "app" else { return false }
        guard let bundle = Bundle(url: url), let id = bundle.bundleIdentifier else { return false }
        if !bundleIDs.contains(id) {
            bundleIDs.append(id)
            return true
        }
        return false
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            handled = true
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url = url else { return }
                DispatchQueue.main.async {
                    _ = add(url: url)
                }
            }
        }
        return handled
    }

    // MARK: - NSWorkspace lookup

    private func appName(for bundleID: String) -> String? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        return FileManager.default.displayName(atPath: url.path)
    }

    private func appIcon(for bundleID: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}
