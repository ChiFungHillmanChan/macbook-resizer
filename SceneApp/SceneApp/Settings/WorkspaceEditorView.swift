import SwiftUI
import SceneCore

/// Workspace editor — basics (name / layout / hotkey), apps (launch / quit),
/// focus (Shortcut names), and triggers. Saved to the store via
/// `WorkspaceStoreViewModel.update(_:)` which enforces strict update semantics
/// (throws on missing ID) and cross-store hotkey conflict detection.
///
/// Interpolated error messages use `String(format: String(localized:), arg)`
/// per Cross-cutting §1 — the catalog key carries a `%@` placeholder.
struct WorkspaceEditorView: View {
    @State private var draft: Workspace
    let originalID: UUID
    @ObservedObject var workspaceStore: WorkspaceStoreViewModel
    @ObservedObject var layoutStore: LayoutStoreViewModel
    let calendarPermissionRequester: () async -> Bool
    @State private var saveError: String?

    init(
        workspace: Workspace,
        workspaceStore: WorkspaceStoreViewModel,
        layoutStore: LayoutStoreViewModel,
        calendarPermissionRequester: @escaping () async -> Bool = { true }
    ) {
        self._draft = State(initialValue: workspace)
        self.originalID = workspace.id
        self.workspaceStore = workspaceStore
        self.layoutStore = layoutStore
        self.calendarPermissionRequester = calendarPermissionRequester
    }

    var body: some View {
        Form {
            Section("workspace.editor.section.basics") {
                TextField("workspace.editor.name", text: $draft.name)
                LayoutPickerView(
                    selectedID: $draft.layoutID,
                    layoutStore: layoutStore
                )
                HotkeyField(chord: $draft.hotkey)
            }
            Section("workspace.editor.section.apps") {
                AppPickerView(bundleIDs: $draft.appsToLaunch, label: "workspace.editor.apps_to_launch")
                AppPickerView(bundleIDs: $draft.appsToQuit,   label: "workspace.editor.apps_to_quit")
            }
            Section("workspace.editor.section.focus") {
                TextField(
                    "workspace.editor.focus.shortcut_on",
                    text: .init(
                        get: { draft.focusMode?.shortcutNameOn ?? "" },
                        set: { newValue in
                            var f = draft.focusMode ?? FocusModeReference()
                            f.shortcutNameOn = newValue.isEmpty ? nil : newValue
                            draft.focusMode = (f.shortcutNameOn == nil && f.shortcutNameOff == nil) ? nil : f
                        }
                    )
                )
                TextField(
                    "workspace.editor.focus.shortcut_off",
                    text: .init(
                        get: { draft.focusMode?.shortcutNameOff ?? "" },
                        set: { newValue in
                            var f = draft.focusMode ?? FocusModeReference()
                            f.shortcutNameOff = newValue.isEmpty ? nil : newValue
                            draft.focusMode = (f.shortcutNameOn == nil && f.shortcutNameOff == nil) ? nil : f
                        }
                    )
                )
                Text("workspace.editor.focus.hint").font(.caption).foregroundStyle(.secondary)
            }
            Section("workspace.editor.section.triggers") {
                WorkspaceTriggerEditor(
                    triggers: $draft.triggers,
                    calendarPermissionRequester: calendarPermissionRequester
                )
            }
            if let err = saveError {
                Text(err).foregroundStyle(.red).font(.caption)
            }
            HStack {
                Spacer()
                Button("workspace.editor.save", action: save).keyboardShortcut(.defaultAction)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func save() {
        do {
            try workspaceStore.update(draft)
            saveError = nil
        } catch WorkspaceStoreError.hotkeyConflict(let resource) {
            saveError = String(format: String(localized: "workspace.editor.error.hotkey_conflict"), resource)
        } catch WorkspaceStoreError.notFound(let id) {
            saveError = String(format: String(localized: "workspace.editor.error.not_found"), id.uuidString)
        } catch {
            saveError = error.localizedDescription
        }
    }
}

/// Compact chord-capture field used inside the Workspace editor. Wraps the
/// existing V0.2 `HotkeyCaptureView` (which uses a callback-style NSView) and
/// adapts it to a `@Binding var chord: HotkeyBinding?` surface.
private struct HotkeyField: View {
    @Binding var chord: HotkeyBinding?
    @State private var recording: Bool = false

    var body: some View {
        HStack {
            Text("workspace.editor.hotkey").frame(width: 120, alignment: .leading)
            if recording {
                HotkeyCaptureView { binding in
                    chord = binding
                    recording = false
                }
                .frame(height: 24)
            } else {
                Text(chord?.displayString ?? String(localized: "workspace.editor.hotkey.none"))
                    .frame(minWidth: 80, alignment: .leading)
                    .foregroundStyle(chord == nil ? .secondary : .primary)
            }
            Spacer()
            Button(recording ? "workspace.editor.hotkey.cancel" : "workspace.editor.hotkey.record") {
                recording.toggle()
            }
            Button("workspace.editor.hotkey.clear") {
                chord = nil
                recording = false
            }
            .disabled(chord == nil)
        }
    }
}
