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

    public init(
        id: UUID, name: String, template: LayoutTemplate,
        slotProportions: [Double], hotkey: HotkeyBinding?,
        isPresetSeed: Bool, isModified: Bool
    ) {
        self.id = id; self.name = name; self.template = template
        self.slotProportions = slotProportions; self.hotkey = hotkey
        self.isPresetSeed = isPresetSeed; self.isModified = isModified
    }

    /// Builds a `Layout` value for `LayoutEngine.plan`. The synthesized `Layout.id` is `.full`
    /// only because the engine ignores it; identity for V0.2 routing is `CustomLayout.id` (UUID).
    /// Do not rely on the returned `LayoutID`.
    public func toLayout() -> Layout {
        Layout(id: .full, name: name, slots: template.slots(proportions: slotProportions))
    }
}
