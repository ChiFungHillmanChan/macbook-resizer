import Foundation

public struct SanitizedLayout: Codable, Sendable, Equatable {
    public let id: UUID
    public let nameHash: String
    public let template: String          // LayoutTemplate.rawValue
    public let slotProportions: [Double]
    public let hotkey: SanitizedHotkey?
    public let isPresetSeed: Bool
    public let isModified: Bool
    public let hasCustomTree: Bool       // boolean only; tree contents redacted

    public init(
        id: UUID,
        nameHash: String,
        template: String,
        slotProportions: [Double],
        hotkey: SanitizedHotkey?,
        isPresetSeed: Bool,
        isModified: Bool,
        hasCustomTree: Bool
    ) {
        self.id = id
        self.nameHash = nameHash
        self.template = template
        self.slotProportions = slotProportions
        self.hotkey = hotkey
        self.isPresetSeed = isPresetSeed
        self.isModified = isModified
        self.hasCustomTree = hasCustomTree
    }
}
