import XCTest
@testable import SceneCore

final class WorkspaceTests: XCTestCase {
    func testFullRoundTrip() throws {
        let id = UUID()
        let layoutID = UUID()
        let hotkey = HotkeyBinding(keyCode: 18, modifiers: [.command, .option])
        let focus = FocusModeReference(shortcutNameOn: "Coding Focus On", shortcutNameOff: "Coding Focus Off")
        let trigger1: WorkspaceTrigger = .manual
        let trigger2: WorkspaceTrigger = .monitorConnect(displayName: "DELL U2723QE")

        let original = Workspace(
            id: id,
            name: "Coding",
            layoutID: layoutID,
            appsToLaunch: ["com.apple.Safari", "com.google.Chrome"],
            appsToQuit: ["com.tinyspeck.slackmacgap"],
            focusMode: focus,
            hotkey: hotkey,
            triggers: [trigger1, trigger2],
            isPresetSeed: true,
            isModified: false
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Workspace.self, from: encoded)
        XCTAssertEqual(decoded, original)
    }

    func testNilFocusAndHotkeyRoundTrip() throws {
        let original = Workspace(
            id: UUID(),
            name: "Reading",
            layoutID: UUID(),
            appsToLaunch: [],
            appsToQuit: [],
            focusMode: nil,
            hotkey: nil,
            triggers: [],
            isPresetSeed: false,
            isModified: false
        )
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Workspace.self, from: encoded)
        XCTAssertNil(decoded.focusMode)
        XCTAssertNil(decoded.hotkey)
        XCTAssertTrue(decoded.appsToLaunch.isEmpty)
    }

    func testIdentifiableConformance() {
        let w = Workspace(id: UUID(), name: "X", layoutID: UUID(),
                          appsToLaunch: [], appsToQuit: [],
                          focusMode: nil, hotkey: nil, triggers: [],
                          isPresetSeed: false, isModified: false)
        XCTAssertEqual(w.id, w.id) // Identifiable compiles
    }
}
