import Foundation
import Carbon.HIToolbox

public enum PresetSeeds {
    public static let fullID            = UUID(uuidString: "11111111-0001-0000-0000-000000000001")!
    public static let halvesID          = UUID(uuidString: "11111111-0002-0000-0000-000000000002")!
    public static let thirdsID          = UUID(uuidString: "11111111-0003-0000-0000-000000000003")!
    public static let quadsID           = UUID(uuidString: "11111111-0004-0000-0000-000000000004")!
    public static let mainSideID        = UUID(uuidString: "11111111-0005-0000-0000-000000000005")!
    public static let leftSplitRightID  = UUID(uuidString: "11111111-0006-0000-0000-000000000006")!
    public static let leftRightSplitID  = UUID(uuidString: "11111111-0007-0000-0000-000000000007")!

    public static var all: [CustomLayout] {
        [
            CustomLayout(id: fullID, name: "Full", template: .single, slotProportions: [],
                         hotkey: HotkeyBinding(keyCode: UInt32(kVK_ANSI_1), modifiers: [.command, .shift]),
                         isPresetSeed: true, isModified: false),
            CustomLayout(id: halvesID, name: "Halves", template: .twoCol, slotProportions: [0.5],
                         hotkey: HotkeyBinding(keyCode: UInt32(kVK_ANSI_2), modifiers: [.command, .shift]),
                         isPresetSeed: true, isModified: false),
            CustomLayout(id: thirdsID, name: "Thirds", template: .threeCol, slotProportions: [1.0/3.0, 2.0/3.0],
                         hotkey: HotkeyBinding(keyCode: UInt32(kVK_ANSI_3), modifiers: [.command, .shift]),
                         isPresetSeed: true, isModified: false),
            CustomLayout(id: quadsID, name: "Quads", template: .grid2x2, slotProportions: [0.5, 0.5],
                         hotkey: HotkeyBinding(keyCode: UInt32(kVK_ANSI_4), modifiers: [.command, .shift]),
                         isPresetSeed: true, isModified: false),
            CustomLayout(id: mainSideID, name: "Main + Side", template: .twoCol, slotProportions: [0.7],
                         hotkey: HotkeyBinding(keyCode: UInt32(kVK_ANSI_5), modifiers: [.command, .shift]),
                         isPresetSeed: true, isModified: false),
            CustomLayout(id: leftSplitRightID, name: "LeftSplit + Right", template: .lShapeRight, slotProportions: [0.5, 0.5],
                         hotkey: HotkeyBinding(keyCode: UInt32(kVK_ANSI_6), modifiers: [.command, .shift]),
                         isPresetSeed: true, isModified: false),
            CustomLayout(id: leftRightSplitID, name: "Left + RightSplit", template: .lShapeLeft, slotProportions: [0.5, 0.5],
                         hotkey: HotkeyBinding(keyCode: UInt32(kVK_ANSI_7), modifiers: [.command, .shift]),
                         isPresetSeed: true, isModified: false),
        ]
    }

    public static var allUUIDs: Set<UUID> { Set(all.map(\.id)) }
}
