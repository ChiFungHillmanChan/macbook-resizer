import Foundation
import CoreGraphics

public struct CustomLayout: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var template: LayoutTemplate
    public var slotProportions: [Double]
    public var hotkey: HotkeyBinding?
    public var isPresetSeed: Bool
    public var isModified: Bool
    /// V0.7 freeform "custom layout build" — when non-nil, `toLayout()` ignores
    /// `template` / `slotProportions` and flattens this tree into slots. Lets
    /// users author arbitrary split-based layouts beyond the fixed 11 templates.
    /// Nil (default) preserves the V0.2 template-based behaviour.
    public var customTree: LayoutNode?

    public init(
        id: UUID, name: String, template: LayoutTemplate,
        slotProportions: [Double], hotkey: HotkeyBinding?,
        isPresetSeed: Bool, isModified: Bool,
        customTree: LayoutNode? = nil
    ) {
        self.id = id; self.name = name; self.template = template
        self.slotProportions = slotProportions; self.hotkey = hotkey
        self.isPresetSeed = isPresetSeed; self.isModified = isModified
        self.customTree = customTree
    }

    /// Builds a `Layout` value for `LayoutEngine.plan`. The synthesized `Layout.id` is `.full`
    /// only because the engine ignores it; identity for V0.2 routing is `CustomLayout.id` (UUID).
    /// Do not rely on the returned `LayoutID`.
    ///
    /// V0.7: when `customTree` is present, slots come from its `flatten()` output instead
    /// of the template. The tree's unit-rect slots pass straight through to
    /// `LayoutEngine.plan`, which already materializes them via
    /// `Slot.absoluteRect(in: visibleFrame)` — no engine changes needed.
    public func toLayout() -> Layout {
        if let tree = customTree {
            return Layout(id: .full, name: name, slots: tree.flatten())
        }
        return Layout(id: .full, name: name, slots: template.slots(proportions: slotProportions))
    }

    // MARK: - Codable (backward-compatible)

    private enum CodingKeys: String, CodingKey {
        case id, name, template, slotProportions, hotkey,
             isPresetSeed, isModified, customTree
    }

    /// Decodes legacy JSON (pre-V0.7) that lacks `customTree`, plus current
    /// JSON that includes it. Absence of `customTree` → template mode.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.name = try c.decode(String.self, forKey: .name)
        self.template = try c.decode(LayoutTemplate.self, forKey: .template)
        self.slotProportions = try c.decode([Double].self, forKey: .slotProportions)
        self.hotkey = try c.decodeIfPresent(HotkeyBinding.self, forKey: .hotkey)
        self.isPresetSeed = try c.decode(Bool.self, forKey: .isPresetSeed)
        self.isModified = try c.decode(Bool.self, forKey: .isModified)
        self.customTree = try c.decodeIfPresent(LayoutNode.self, forKey: .customTree)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(template, forKey: .template)
        try c.encode(slotProportions, forKey: .slotProportions)
        try c.encodeIfPresent(hotkey, forKey: .hotkey)
        try c.encode(isPresetSeed, forKey: .isPresetSeed)
        try c.encode(isModified, forKey: .isModified)
        // `encodeIfPresent` so old-style layouts still produce JSON with no
        // `customTree` key — keeps the on-disk format minimal and lets older
        // tools / eyes read the file without seeing an unfamiliar nested blob.
        try c.encodeIfPresent(customTree, forKey: .customTree)
    }
}
