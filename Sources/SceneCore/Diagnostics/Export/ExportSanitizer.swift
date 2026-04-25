import Foundation

/// Pure transformation from raw store types into the sanitized DTOs that
/// ship inside an export bundle. Every user-authored string is replaced
/// with a `DiagnosticHasher` token using the export's salt; bundle IDs,
/// names, monitor names, calendar keywords, and Focus shortcut names
/// MUST NOT survive this pass in plaintext.
///
/// Pure: no FileManager, no Process, no I/O. The SceneApp `DiagnosticExporter`
/// (M4) is responsible for reading raw stores, calling these helpers,
/// JSON-encoding the result, and zipping it.
public enum ExportSanitizer {
    public static func sanitize(_ layout: CustomLayout, hasher: DiagnosticHasher) -> SanitizedLayout {
        SanitizedLayout(
            id: layout.id,
            nameHash: hasher.hash(layout.name),
            template: layout.template.rawValue,
            slotProportions: layout.slotProportions,
            hotkey: layout.hotkey.map(SanitizedHotkey.init),
            isPresetSeed: layout.isPresetSeed,
            isModified: layout.isModified,
            hasCustomTree: layout.customTree != nil
        )
    }

    public static func sanitize(_ workspace: Workspace, hasher: DiagnosticHasher) -> SanitizedWorkspace {
        SanitizedWorkspace(
            id: workspace.id,
            nameHash: hasher.hash(workspace.name),
            layoutID: workspace.layoutID,
            assignedDesktop: workspace.assignedDesktop,
            pinnedAppHashes: workspace.pinnedApps.map(hasher.hash),
            appsToLaunchHashes: workspace.appsToLaunch.map(hasher.hash),
            appsToQuitHashes: workspace.appsToQuit.map(hasher.hash),
            enforcementMode: workspace.enforcementMode.rawValue,
            focusMode: workspace.focusMode.map { fm in
                SanitizedFocusMode(
                    onShortcutNameHash: fm.shortcutNameOn.map(hasher.hash),
                    offShortcutNameHash: fm.shortcutNameOff.map(hasher.hash)
                )
            },
            hotkey: workspace.hotkey.map(SanitizedHotkey.init),
            triggers: workspace.triggers.map { sanitize($0, hasher: hasher) },
            isPresetSeed: workspace.isPresetSeed,
            isModified: workspace.isModified
        )
    }

    public static func sanitize(_ trigger: WorkspaceTrigger, hasher: DiagnosticHasher) -> SanitizedTrigger {
        switch trigger {
        case .manual:
            return .manual
        case .monitorConnect(let name):
            return .monitorConnect(displayNameHash: hasher.hash(name))
        case .monitorDisconnect(let name):
            return .monitorDisconnect(displayNameHash: hasher.hash(name))
        case .timeOfDay(let mask, let hr, let mn):
            return .timeOfDay(weekdayMaskRaw: mask.rawValue, hour: hr, minute: mn)
        case .calendarEvent(let kw):
            return .calendarEvent(keywordHash: hasher.hash(kw))
        }
    }

    public static func sanitize(layouts: [CustomLayout], hasher: DiagnosticHasher) -> [SanitizedLayout] {
        layouts.map { sanitize($0, hasher: hasher) }
    }

    public static func sanitize(workspaces: [Workspace], hasher: DiagnosticHasher) -> [SanitizedWorkspace] {
        workspaces.map { sanitize($0, hasher: hasher) }
    }
}
