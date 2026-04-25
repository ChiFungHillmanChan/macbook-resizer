import XCTest
@testable import SceneCore

final class ExportSanitizerTests: XCTestCase {
    private let salt = Data((0..<32).map { UInt8($0) })
    private var hasher: DiagnosticHasher { DiagnosticHasher(salt: salt) }

    private func sampleLayout(name: String = "John's Slack thing") -> CustomLayout {
        CustomLayout(
            id: UUID(uuidString: "AAAAAAAA-1111-2222-3333-444444444444")!,
            name: name,
            template: .twoCol,
            slotProportions: [0.6],
            hotkey: HotkeyBinding(keyCode: 18, modifiers: [.command, .control]),
            isPresetSeed: false,
            isModified: true,
            customTree: nil
        )
    }

    private func sampleWorkspace(
        name: String = "John's Coding",
        bundles: [String] = ["com.tinyspeck.slackmacgap", "com.google.Chrome"]
    ) -> Workspace {
        Workspace(
            id: UUID(uuidString: "BBBBBBBB-1111-2222-3333-444444444444")!,
            name: name,
            layoutID: UUID(uuidString: "AAAAAAAA-1111-2222-3333-444444444444")!,
            assignedDesktop: 3,
            pinnedApps: ["com.apple.dt.Xcode"],
            appsToLaunch: bundles,
            appsToQuit: ["com.skype.skype"],
            enforcementMode: .hideWhenInactive,
            focusMode: FocusModeReference(
                shortcutNameOn: "Set DnD On (John)",
                shortcutNameOff: "Turn Off DnD"
            ),
            hotkey: HotkeyBinding(keyCode: 19, modifiers: [.command, .option]),
            triggers: [
                .manual,
                .monitorConnect(displayName: "DELL U2723QE"),
                .calendarEvent(keywordContains: "Standup"),
                .timeOfDay(weekdayMask: .weekdays, hour: 9, minute: 30),
            ],
            isPresetSeed: false,
            isModified: true
        )
    }

    // MARK: - PII drop

    func testSanitizedLayoutDropsName() throws {
        let layout = sampleLayout(name: "Joseph's secret layout")
        let sanitized = ExportSanitizer.sanitize(layout, hasher: hasher)
        let json = String(data: try JSONEncoder().encode(sanitized), encoding: .utf8) ?? ""
        XCTAssertFalse(json.contains("Joseph"))
        XCTAssertFalse(json.contains("secret"))
        XCTAssertEqual(sanitized.id, layout.id)
        XCTAssertEqual(sanitized.template, "twoCol")
    }

    func testSanitizedWorkspaceDropsAllUserText() throws {
        let ws = sampleWorkspace()
        let sanitized = ExportSanitizer.sanitize(ws, hasher: hasher)
        let json = String(data: try JSONEncoder().encode(sanitized), encoding: .utf8) ?? ""

        // No workspace name / bundle IDs / monitor name / calendar keyword /
        // Focus shortcut name should appear in plaintext.
        for needle in [
            "John", "Coding",
            "tinyspeck", "slackmacgap", "google", "Chrome", "skype",
            "apple", "Xcode",
            "DELL", "U2723QE",
            "Standup",
            "DnD",
        ] {
            XCTAssertFalse(json.contains(needle), "leak: \"\(needle)\" found in sanitized JSON")
        }

        // IDs and structural data preserved
        XCTAssertEqual(sanitized.id, ws.id)
        XCTAssertEqual(sanitized.layoutID, ws.layoutID)
        XCTAssertEqual(sanitized.assignedDesktop, ws.assignedDesktop)
        XCTAssertEqual(sanitized.pinnedAppHashes.count, ws.pinnedApps.count)
        XCTAssertEqual(sanitized.enforcementMode, ws.enforcementMode.rawValue)
        XCTAssertEqual(sanitized.appsToLaunchHashes.count, ws.appsToLaunch.count)
        XCTAssertEqual(sanitized.appsToQuitHashes.count, ws.appsToQuit.count)
        XCTAssertEqual(sanitized.triggers.count, ws.triggers.count)
        XCTAssertEqual(sanitized.isPresetSeed, ws.isPresetSeed)
        XCTAssertEqual(sanitized.isModified, ws.isModified)
    }

    func testSanitizedTriggerCases() {
        let h = hasher
        XCTAssertEqual(
            ExportSanitizer.sanitize(.manual, hasher: h),
            .manual
        )
        let monitor = ExportSanitizer.sanitize(
            .monitorConnect(displayName: "LG ULTRAWIDE"), hasher: h
        )
        if case let .monitorConnect(hash) = monitor {
            XCTAssertEqual(hash.count, 11)
            XCTAssertNotEqual(hash, "LG ULTRAWIDE")
        } else {
            XCTFail("expected monitorConnect")
        }
        let cal = ExportSanitizer.sanitize(
            .calendarEvent(keywordContains: "Standup"), hasher: h
        )
        if case let .calendarEvent(hash) = cal {
            XCTAssertEqual(hash.count, 11)
            XCTAssertNotEqual(hash, "Standup")
        } else {
            XCTFail("expected calendarEvent")
        }
        let tod = ExportSanitizer.sanitize(
            .timeOfDay(weekdayMask: .weekdays, hour: 9, minute: 30), hasher: h
        )
        if case let .timeOfDay(maskRaw, hr, mn) = tod {
            XCTAssertEqual(maskRaw, WorkspaceTrigger.WeekdayMask.weekdays.rawValue)
            XCTAssertEqual(hr, 9)
            XCTAssertEqual(mn, 30)
        } else {
            XCTFail("expected timeOfDay")
        }
    }

    // MARK: - Within-bundle correlation

    func testSameBundleIDHashesEqualWithinSameSalt() {
        let ws = Workspace(
            id: UUID(), name: "X",
            layoutID: UUID(),
            appsToLaunch: ["com.tinyspeck.slackmacgap"],
            appsToQuit: ["com.tinyspeck.slackmacgap"]
        )
        let s = ExportSanitizer.sanitize(ws, hasher: hasher)
        XCTAssertEqual(s.appsToLaunchHashes.first, s.appsToQuitHashes.first,
            "within one bundle, same plaintext should map to same hash for correlation")
    }

    func testDifferentSaltBreaksCorrelation() {
        let other = DiagnosticHasher(salt: Data([0xFF, 0xEE, 0xDD]))
        let a = ExportSanitizer.sanitize(
            sampleWorkspace(), hasher: hasher
        )
        let b = ExportSanitizer.sanitize(
            sampleWorkspace(), hasher: other
        )
        XCTAssertNotEqual(a.nameHash, b.nameHash)
        XCTAssertNotEqual(a.appsToLaunchHashes, b.appsToLaunchHashes)
    }

    // MARK: - Codable round-trip on sanitized DTOs

    func testSanitizedWorkspaceRoundTrip() throws {
        let original = ExportSanitizer.sanitize(sampleWorkspace(), hasher: hasher)
        let data = try JSONEncoder().encode(original)
        let back = try JSONDecoder().decode(SanitizedWorkspace.self, from: data)
        XCTAssertEqual(back, original)
    }

    func testSanitizedLayoutRoundTrip() throws {
        let original = ExportSanitizer.sanitize(sampleLayout(), hasher: hasher)
        let data = try JSONEncoder().encode(original)
        let back = try JSONDecoder().decode(SanitizedLayout.self, from: data)
        XCTAssertEqual(back, original)
    }
}
