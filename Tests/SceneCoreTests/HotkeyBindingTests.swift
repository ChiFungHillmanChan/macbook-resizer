import XCTest
import Carbon.HIToolbox
@testable import SceneCore

final class HotkeyBindingTests: XCTestCase {
    func testCarbonModifiersBridge() {
        let b = HotkeyBinding(keyCode: UInt32(kVK_ANSI_A), modifiers: [.command, .shift])
        XCTAssertEqual(b.carbonModifiers, UInt32(cmdKey | shiftKey))
    }

    func testCarbonAllFour() {
        let b = HotkeyBinding(
            keyCode: UInt32(kVK_ANSI_A),
            modifiers: [.command, .shift, .option, .control]
        )
        XCTAssertEqual(b.carbonModifiers, UInt32(cmdKey | shiftKey | optionKey | controlKey))
    }

    func testCodableRoundTripPreservesModifiers() throws {
        let original = HotkeyBinding(
            keyCode: UInt32(kVK_ANSI_A),
            modifiers: [.command, .shift, .option]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HotkeyBinding.self, from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.modifiers, original.modifiers)
    }

    func testEqualityDoesNotDependOnModifierOrder() {
        let a = HotkeyBinding(keyCode: 1, modifiers: [.command, .shift, .option])
        let b = HotkeyBinding(keyCode: 1, modifiers: [.option, .command, .shift])
        XCTAssertEqual(a, b)
    }

    func testConflictsDetectsSameChord() {
        let a = HotkeyBinding(keyCode: UInt32(kVK_ANSI_A), modifiers: [.command, .shift])
        let b = HotkeyBinding(keyCode: UInt32(kVK_ANSI_A), modifiers: [.shift, .command])
        XCTAssertTrue(a.conflicts(with: b))
        XCTAssertTrue(b.conflicts(with: a))
    }

    func testConflictsRejectsDifferentChord() {
        let a = HotkeyBinding(keyCode: UInt32(kVK_ANSI_A), modifiers: [.command, .shift])
        let b = HotkeyBinding(keyCode: UInt32(kVK_ANSI_B), modifiers: [.command, .shift])
        XCTAssertFalse(a.conflicts(with: b))
        let c = HotkeyBinding(keyCode: UInt32(kVK_ANSI_A), modifiers: [.command])
        XCTAssertFalse(a.conflicts(with: c))
    }

    func testDisplayStringIncludesGlyphs() {
        let b = HotkeyBinding(keyCode: UInt32(kVK_ANSI_A), modifiers: [.command, .shift])
        let s = b.displayString
        XCTAssertTrue(s.contains("\u{2318}"), "missing command glyph in \(s)")
        XCTAssertTrue(s.contains("\u{21E7}"), "missing shift glyph in \(s)")
        XCTAssertTrue(s.contains("A"), "missing key letter in \(s)")
    }
}
