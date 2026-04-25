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
    /// Last-saved snapshot. `draft != savedBaseline` ⇒ unsaved changes ⇒
    /// Save button is enabled. After a successful save the baseline is
    /// promoted to `draft` so the button disables again.
    @State private var savedBaseline: Workspace
    /// Set to true on successful save, cleared 2 s later (or on next
    /// edit). Drives the "Saved ✓" feedback that flashes next to the
    /// Save button so users no longer guess whether the click registered.
    @State private var justSaved: Bool = false
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
        self._savedBaseline = State(initialValue: workspace)
        self.originalID = workspace.id
        self.workspaceStore = workspaceStore
        self.layoutStore = layoutStore
        self.calendarPermissionRequester = calendarPermissionRequester
    }

    private var isDirty: Bool { draft != savedBaseline }

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
            Section("workspace.editor.section.persistent") {
                AppPickerView(bundleIDs: $draft.pinnedApps, label: "workspace.editor.pinned_apps")
                Toggle("workspace.editor.desktop.assign", isOn: isDesktopAssigned)
                if draft.assignedDesktop != nil {
                    Stepper(value: desktopNumber, in: 1...9) {
                        Text(String(
                            format: String(localized: "workspace.editor.desktop.number"),
                            draft.assignedDesktop ?? 1
                        ))
                    }
                }
                Text("workspace.editor.desktop.hint")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("workspace.editor.enforcement", selection: $draft.enforcementMode) {
                    ForEach(WorkspaceEnforcementMode.allCases, id: \.self) { mode in
                        Text(enforcementTitle(for: mode)).tag(mode)
                    }
                }
                Text(enforcementDescription(for: draft.enforcementMode))
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
            HStack(spacing: 8) {
                Spacer()
                if justSaved && !isDirty {
                    Label("workspace.editor.saved", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                        .transition(.opacity)
                } else if isDirty {
                    Text("workspace.editor.unsaved")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .transition(.opacity)
                }
                Button("workspace.editor.save", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isDirty)
            }
            .animation(.easeInOut(duration: 0.18), value: justSaved)
            .animation(.easeInOut(duration: 0.18), value: isDirty)
        }
        .formStyle(.grouped)
        .padding()
        .onChange(of: draft) { _, _ in
            // Editing while the "Saved" badge is still up — drop it so
            // the user can't mistake unsaved edits for saved state.
            if justSaved { justSaved = false }
        }
    }

    private var isDesktopAssigned: Binding<Bool> {
        Binding(
            get: { draft.assignedDesktop != nil },
            set: { enabled in
                draft.assignedDesktop = enabled ? (draft.assignedDesktop ?? 1) : nil
            }
        )
    }

    private var desktopNumber: Binding<Int> {
        Binding(
            get: { draft.assignedDesktop ?? 1 },
            set: { draft.assignedDesktop = min(max($0, 1), 9) }
        )
    }

    private func save() {
        do {
            try workspaceStore.update(draft)
            saveError = nil
            savedBaseline = draft
            justSaved = true
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                // Only clear if no further edit has already cleared it.
                if justSaved { justSaved = false }
            }
        } catch WorkspaceStoreError.hotkeyConflict(let resource) {
            saveError = String(format: String(localized: "workspace.editor.error.hotkey_conflict"), resource)
        } catch WorkspaceStoreError.notFound(let id) {
            saveError = String(format: String(localized: "workspace.editor.error.not_found"), id.uuidString)
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func enforcementTitle(for mode: WorkspaceEnforcementMode) -> LocalizedStringKey {
        switch mode {
        case .off:
            return "workspace.editor.enforcement.off"
        case .arrangeOnly:
            return "workspace.editor.enforcement.arrange_only"
        case .hideWhenInactive:
            return "workspace.editor.enforcement.hide_when_inactive"
        case .quitWhenInactive:
            return "workspace.editor.enforcement.quit_when_inactive"
        }
    }

    private func enforcementDescription(for mode: WorkspaceEnforcementMode) -> LocalizedStringKey {
        switch mode {
        case .off:
            return "workspace.editor.enforcement.off.hint"
        case .arrangeOnly:
            return "workspace.editor.enforcement.arrange_only.hint"
        case .hideWhenInactive:
            return "workspace.editor.enforcement.hide_when_inactive.hint"
        case .quitWhenInactive:
            return "workspace.editor.enforcement.quit_when_inactive.hint"
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
