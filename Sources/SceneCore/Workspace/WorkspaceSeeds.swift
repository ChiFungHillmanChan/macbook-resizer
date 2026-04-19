import Foundation
import Carbon.HIToolbox

/// The 4 built-in Workspace templates shipped with V0.4. Each seed has:
///   - a stable UUID (persisted in users' workspaces.json; never change)
///   - a sensible default layout from `PresetSeeds` (referenced by UUID)
///   - an empty `appsToLaunch` / `appsToQuit` (user customizes)
///   - a ⌘⌥-prefixed hotkey (⌘⌥1-4, reserved space for Workspaces)
///   - `isPresetSeed: true`, `isModified: false`
public enum WorkspaceSeeds {
    public static let codingID    = UUID(uuidString: "22222222-0001-0000-0000-000000000001")!
    public static let meetingID   = UUID(uuidString: "22222222-0002-0000-0000-000000000002")!
    public static let readingID   = UUID(uuidString: "22222222-0003-0000-0000-000000000003")!
    public static let streamingID = UUID(uuidString: "22222222-0004-0000-0000-000000000004")!

    public static let all: [Workspace] = [
        Workspace(
            id: codingID,
            name: "Coding",
            // Coding: 70/30 main+side two-col — `PresetSeeds.mainSideID` (the V0.1 equivalent
            // of the plan's `leftRight70ID`; see PresetSeeds.swift).
            layoutID: PresetSeeds.mainSideID,
            appsToLaunch: [],
            appsToQuit: [],
            focusMode: nil,
            hotkey: HotkeyBinding(keyCode: UInt32(kVK_ANSI_1), modifiers: [.command, .option]),
            triggers: [],
            isPresetSeed: true,
            isModified: false
        ),
        Workspace(
            id: meetingID,
            name: "Meeting",
            layoutID: PresetSeeds.halvesVerticalID,
            appsToLaunch: [],
            appsToQuit: [],
            focusMode: nil,
            hotkey: HotkeyBinding(keyCode: UInt32(kVK_ANSI_2), modifiers: [.command, .option]),
            triggers: [],
            isPresetSeed: true,
            isModified: false
        ),
        Workspace(
            id: readingID,
            name: "Reading",
            layoutID: PresetSeeds.fullID,
            appsToLaunch: [],
            appsToQuit: [],
            focusMode: nil,
            hotkey: HotkeyBinding(keyCode: UInt32(kVK_ANSI_3), modifiers: [.command, .option]),
            triggers: [],
            isPresetSeed: true,
            isModified: false
        ),
        Workspace(
            id: streamingID,
            name: "Streaming",
            // Streaming: 2x2 grid — `PresetSeeds.quadsID` (the V0.1 equivalent of
            // the plan's `grid2x2ID`).
            layoutID: PresetSeeds.quadsID,
            appsToLaunch: [],
            appsToQuit: [],
            focusMode: nil,
            hotkey: HotkeyBinding(keyCode: UInt32(kVK_ANSI_4), modifiers: [.command, .option]),
            triggers: [],
            isPresetSeed: true,
            isModified: false
        ),
    ]
}
