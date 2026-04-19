import Foundation

/// A Scene Workspace ("情境") bundles a layout + apps to launch + apps to quit
/// + Focus mode + hotkey + triggers. Activating a Workspace = one-click switch
/// between productivity contexts (Coding / Meeting / Reading / Streaming).
///
/// Pure value type; `WorkspaceStore` manages persistence and identity; the
/// SceneApp `WorkspaceActivator` consumes an instance and performs the apply.
public struct Workspace: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    /// References `CustomLayout.id`. If the referenced layout is deleted,
    /// `referencedLayout(in:)` returns nil; UI should flag the Workspace red
    /// and prevent activation until user re-picks.
    public var layoutID: UUID
    /// Bundle IDs, e.g., "com.google.Chrome". Stable across app moves.
    public var appsToLaunch: [String]
    public var appsToQuit: [String]
    public var focusMode: FocusModeReference?
    public var hotkey: HotkeyBinding?
    public var triggers: [WorkspaceTrigger]
    public var isPresetSeed: Bool
    public var isModified: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        layoutID: UUID,
        appsToLaunch: [String] = [],
        appsToQuit: [String] = [],
        focusMode: FocusModeReference? = nil,
        hotkey: HotkeyBinding? = nil,
        triggers: [WorkspaceTrigger] = [],
        isPresetSeed: Bool = false,
        isModified: Bool = false
    ) {
        self.id = id
        self.name = name
        self.layoutID = layoutID
        self.appsToLaunch = appsToLaunch
        self.appsToQuit = appsToQuit
        self.focusMode = focusMode
        self.hotkey = hotkey
        self.triggers = triggers
        self.isPresetSeed = isPresetSeed
        self.isModified = isModified
    }
}
