import Foundation

public struct SanitizedWorkspace: Codable, Sendable, Equatable {
    public let id: UUID
    public let nameHash: String
    public let layoutID: UUID
    public let assignedDesktop: Int?
    public let pinnedAppHashes: [String]
    public let appsToLaunchHashes: [String]
    public let appsToQuitHashes: [String]
    public let enforcementMode: String
    public let focusMode: SanitizedFocusMode?
    public let hotkey: SanitizedHotkey?
    public let triggers: [SanitizedTrigger]
    public let isPresetSeed: Bool
    public let isModified: Bool

    public init(
        id: UUID,
        nameHash: String,
        layoutID: UUID,
        assignedDesktop: Int?,
        pinnedAppHashes: [String],
        appsToLaunchHashes: [String],
        appsToQuitHashes: [String],
        enforcementMode: String,
        focusMode: SanitizedFocusMode?,
        hotkey: SanitizedHotkey?,
        triggers: [SanitizedTrigger],
        isPresetSeed: Bool,
        isModified: Bool
    ) {
        self.id = id
        self.nameHash = nameHash
        self.layoutID = layoutID
        self.assignedDesktop = assignedDesktop
        self.pinnedAppHashes = pinnedAppHashes
        self.appsToLaunchHashes = appsToLaunchHashes
        self.appsToQuitHashes = appsToQuitHashes
        self.enforcementMode = enforcementMode
        self.focusMode = focusMode
        self.hotkey = hotkey
        self.triggers = triggers
        self.isPresetSeed = isPresetSeed
        self.isModified = isModified
    }
}
