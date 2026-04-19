import Foundation
import Carbon.HIToolbox

public enum PresetSeeds {
    // V0.1 stable UUIDs
    public static let fullID            = UUID(uuidString: "11111111-0001-0000-0000-000000000001")!
    public static let halvesID          = UUID(uuidString: "11111111-0002-0000-0000-000000000002")!
    public static let thirdsID          = UUID(uuidString: "11111111-0003-0000-0000-000000000003")!
    public static let quadsID           = UUID(uuidString: "11111111-0004-0000-0000-000000000004")!
    public static let mainSideID        = UUID(uuidString: "11111111-0005-0000-0000-000000000005")!
    public static let leftSplitRightID  = UUID(uuidString: "11111111-0006-0000-0000-000000000006")!
    public static let leftRightSplitID  = UUID(uuidString: "11111111-0007-0000-0000-000000000007")!

    // V0.4 vertical seeds
    public static let mainSideVerticalID = UUID(uuidString: "11111111-0008-0000-0000-000000000008")!
    public static let halvesVerticalID   = UUID(uuidString: "11111111-0009-0000-0000-000000000009")!
    public static let thirdsVerticalID   = UUID(uuidString: "11111111-000A-0000-0000-00000000000A")!

    public static var all: [CustomLayout] {
        [
            CustomLayout(id: fullID, name: "Full", template: .single, slotProportions: [],
                         hotkey: HotkeyBinding(keyCode: UInt32(kVK_ANSI_1), modifiers: [.command, .control]),
                         isPresetSeed: true, isModified: false),
            CustomLayout(id: halvesID, name: "Halves", template: .twoCol, slotProportions: [0.5],
                         hotkey: HotkeyBinding(keyCode: UInt32(kVK_ANSI_2), modifiers: [.command, .control]),
                         isPresetSeed: true, isModified: false),
            CustomLayout(id: thirdsID, name: "Thirds", template: .threeCol, slotProportions: [1.0/3.0, 2.0/3.0],
                         hotkey: HotkeyBinding(keyCode: UInt32(kVK_ANSI_3), modifiers: [.command, .control]),
                         isPresetSeed: true, isModified: false),
            CustomLayout(id: quadsID, name: "Quads", template: .grid2x2, slotProportions: [0.5, 0.5],
                         hotkey: HotkeyBinding(keyCode: UInt32(kVK_ANSI_4), modifiers: [.command, .control]),
                         isPresetSeed: true, isModified: false),
            CustomLayout(id: mainSideID, name: "Main + Side", template: .twoCol, slotProportions: [0.7],
                         hotkey: HotkeyBinding(keyCode: UInt32(kVK_ANSI_5), modifiers: [.command, .control]),
                         isPresetSeed: true, isModified: false),
            CustomLayout(id: leftSplitRightID, name: "LeftSplit + Right", template: .lShapeRight, slotProportions: [0.5, 0.5],
                         hotkey: HotkeyBinding(keyCode: UInt32(kVK_ANSI_6), modifiers: [.command, .control]),
                         isPresetSeed: true, isModified: false),
            CustomLayout(id: leftRightSplitID, name: "Left + RightSplit", template: .lShapeLeft, slotProportions: [0.5, 0.5],
                         hotkey: HotkeyBinding(keyCode: UInt32(kVK_ANSI_7), modifiers: [.command, .control]),
                         isPresetSeed: true, isModified: false),
            CustomLayout(id: mainSideVerticalID, name: "Main + Side (Vertical)", template: .twoRow, slotProportions: [0.7],
                         hotkey: HotkeyBinding(keyCode: UInt32(kVK_ANSI_8), modifiers: [.command, .control]),
                         isPresetSeed: true, isModified: false),
            CustomLayout(id: halvesVerticalID, name: "Halves (Vertical)", template: .twoRow, slotProportions: [0.5],
                         hotkey: HotkeyBinding(keyCode: UInt32(kVK_ANSI_9), modifiers: [.command, .control]),
                         isPresetSeed: true, isModified: false),
            CustomLayout(id: thirdsVerticalID, name: "Thirds (Vertical)", template: .threeRow, slotProportions: [1.0/3.0, 2.0/3.0],
                         hotkey: HotkeyBinding(keyCode: UInt32(kVK_ANSI_0), modifiers: [.command, .control]),
                         isPresetSeed: true, isModified: false),
        ]
    }

    public static var allUUIDs: Set<UUID> { Set(all.map(\.id)) }
}
