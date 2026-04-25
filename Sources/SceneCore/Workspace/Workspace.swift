import Foundation

public enum WorkspaceEnforcementMode: String, Codable, CaseIterable, Hashable, Sendable {
    /// Persist the pinned app list and launch it during activation, but do not
    /// police other running apps while the Workspace is active.
    case off
    /// Switch Desktop / launch / arrange only. This is intentionally non-
    /// destructive and leaves other Workspaces' pinned apps alone.
    case arrangeOnly
    /// Hide apps pinned to other Workspaces while this Workspace is active.
    case hideWhenInactive
    /// Ask apps pinned to other Workspaces to quit while this Workspace is active.
    case quitWhenInactive
}

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
    /// Optional Mission Control Desktop number. Scene switches via the user's
    /// macOS "Switch to Desktop N" keyboard shortcut; macOS does not expose a
    /// public API for assigning arbitrary third-party windows to Spaces.
    public var assignedDesktop: Int?
    /// Bundle IDs treated as belonging to this Workspace. They are launched on
    /// activation and may be hidden/quit when another Workspace is active,
    /// depending on that active Workspace's `enforcementMode`.
    public var pinnedApps: [String]
    /// Bundle IDs, e.g., "com.google.Chrome". Stable across app moves.
    public var appsToLaunch: [String]
    public var appsToQuit: [String]
    public var enforcementMode: WorkspaceEnforcementMode
    public var focusMode: FocusModeReference?
    public var hotkey: HotkeyBinding?
    public var triggers: [WorkspaceTrigger]
    public var isPresetSeed: Bool
    public var isModified: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        layoutID: UUID,
        assignedDesktop: Int? = nil,
        pinnedApps: [String] = [],
        appsToLaunch: [String] = [],
        appsToQuit: [String] = [],
        enforcementMode: WorkspaceEnforcementMode = .off,
        focusMode: FocusModeReference? = nil,
        hotkey: HotkeyBinding? = nil,
        triggers: [WorkspaceTrigger] = [],
        isPresetSeed: Bool = false,
        isModified: Bool = false
    ) {
        self.id = id
        self.name = name
        self.layoutID = layoutID
        self.assignedDesktop = assignedDesktop
        self.pinnedApps = pinnedApps
        self.appsToLaunch = appsToLaunch
        self.appsToQuit = appsToQuit
        self.enforcementMode = enforcementMode
        self.focusMode = focusMode
        self.hotkey = hotkey
        self.triggers = triggers
        self.isPresetSeed = isPresetSeed
        self.isModified = isModified
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case layoutID
        case assignedDesktop
        case pinnedApps
        case appsToLaunch
        case appsToQuit
        case enforcementMode
        case focusMode
        case hotkey
        case triggers
        case isPresetSeed
        case isModified
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.name = try c.decode(String.self, forKey: .name)
        self.layoutID = try c.decode(UUID.self, forKey: .layoutID)
        self.assignedDesktop = try c.decodeIfPresent(Int.self, forKey: .assignedDesktop)
        self.pinnedApps = try c.decodeIfPresent([String].self, forKey: .pinnedApps) ?? []
        self.appsToLaunch = try c.decodeIfPresent([String].self, forKey: .appsToLaunch) ?? []
        self.appsToQuit = try c.decodeIfPresent([String].self, forKey: .appsToQuit) ?? []
        self.enforcementMode = try c.decodeIfPresent(
            WorkspaceEnforcementMode.self,
            forKey: .enforcementMode
        ) ?? .off
        self.focusMode = try c.decodeIfPresent(FocusModeReference.self, forKey: .focusMode)
        self.hotkey = try c.decodeIfPresent(HotkeyBinding.self, forKey: .hotkey)
        self.triggers = try c.decodeIfPresent([WorkspaceTrigger].self, forKey: .triggers) ?? []
        self.isPresetSeed = try c.decodeIfPresent(Bool.self, forKey: .isPresetSeed) ?? false
        self.isModified = try c.decodeIfPresent(Bool.self, forKey: .isModified) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(layoutID, forKey: .layoutID)
        try c.encodeIfPresent(assignedDesktop, forKey: .assignedDesktop)
        try c.encode(pinnedApps, forKey: .pinnedApps)
        try c.encode(appsToLaunch, forKey: .appsToLaunch)
        try c.encode(appsToQuit, forKey: .appsToQuit)
        try c.encode(enforcementMode, forKey: .enforcementMode)
        try c.encodeIfPresent(focusMode, forKey: .focusMode)
        try c.encodeIfPresent(hotkey, forKey: .hotkey)
        try c.encode(triggers, forKey: .triggers)
        try c.encode(isPresetSeed, forKey: .isPresetSeed)
        try c.encode(isModified, forKey: .isModified)
    }
}
