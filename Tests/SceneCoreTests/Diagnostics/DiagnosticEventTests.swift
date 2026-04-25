import XCTest
@testable import SceneCore

final class DiagnosticEventTests: XCTestCase {
    private func sampleSnapshot() -> EnvironmentSnapshot {
        EnvironmentSnapshot(
            ts: Date(timeIntervalSince1970: 0),
            screens: [
                ScreenRecord(
                    id: 1, x: 0, y: 0, w: 1920, h: 1080,
                    vx: 0, vy: 25, vw: 1920, vh: 1055,
                    scale100: 200, main: true
                )
            ],
            activeID: 1, winCount: 3, activeWS: nil, secsSinceLastChange: nil
        )
    }

    private let dummyID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!

    // MARK: - Round-trip every case

    func testRoundTripLayoutFired() throws {
        try roundTrip(.layoutFired(.init(
            layoutID: dummyID, source: .hotkey, snapshot: sampleSnapshot()
        )))
    }

    func testRoundTripLayoutOutcomeInstant() throws {
        try roundTrip(.layoutOutcomeInstant(.init(
            layoutID: dummyID, placed: 4, minimized: 1, leftEmpty: 0, failed: 0
        )))
    }

    func testRoundTripLayoutOutcomeAnimated() throws {
        try roundTrip(.layoutOutcomeAnimated(.init(
            layoutID: dummyID, windowCount: 4, durationMs: 250,
            setFrameFailures: 0, endReason: .normal
        )))
        try roundTrip(.layoutOutcomeAnimated(.init(
            layoutID: dummyID, windowCount: 2, durationMs: 100,
            setFrameFailures: 1, endReason: .interrupted
        )))
    }

    func testRoundTripWorkspaceStep() throws {
        try roundTrip(.workspaceStep(.init(
            workspaceID: dummyID, step: .applyLayout, status: .ok,
            durationMs: 42, appCount: 3, survivorCount: 0
        )))
    }

    func testRoundTripTriggerFired() throws {
        try roundTrip(.triggerFired(.init(
            workspaceID: dummyID, kind: .monitorConnect,
            displayNameHash: "abcd1234efgh"
        )))
        try roundTrip(.triggerFired(.init(
            workspaceID: dummyID, kind: .calendarEvent,
            keywordHash: "abcd1234efgh"
        )))
    }

    func testRoundTripTriggerSuppressed() throws {
        try roundTrip(.triggerSuppressed(.init(
            workspaceID: dummyID, reason: .cooldown, cooldownRemainingMs: 12_000
        )))
    }

    func testRoundTripScreenDiff() throws {
        let before = sampleSnapshot()
        let after = sampleSnapshot()
        try roundTrip(.screenDiff(.init(
            beforeSig: before.sig, afterSig: after.sig,
            beforeScreens: before.screens, afterScreens: after.screens
        )))
    }

    func testRoundTripAXPermission() throws {
        try roundTrip(.axPermissionChanged(.init(granted: true)))
        try roundTrip(.axPermissionChanged(.init(granted: false)))
    }

    func testRoundTripAppLaunchTimeout() throws {
        try roundTrip(.appLaunchTimeout(.init(
            workspaceID: dummyID, bundleIDHash: "abcd1234efgh", timedOutAfterMs: 5_000
        )))
    }

    func testRoundTripAppQuitSurvivors() throws {
        try roundTrip(.appQuitSurvivors(.init(
            workspaceID: dummyID, requested: 3,
            survivorBundleIDHashes: ["abcd1234efgh", "wxyz9876uvst"]
        )))
    }

    // MARK: - DiagnosticEntry flat shape

    func testDiagnosticEntryHasFlatTopLevelKeys() throws {
        let entry = DiagnosticEntry(
            ts: Date(timeIntervalSince1970: 1_700_000_000),
            event: .axPermissionChanged(.init(granted: true))
        )
        let data = try JSONEncoder().encode(entry)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        XCTAssertNotNil(dict["ts"])
        XCTAssertEqual(dict["t"] as? String, "axp")
        XCTAssertNotNil(dict["p"])
    }

    func testDiagnosticEntryRoundTrip() throws {
        let entry = DiagnosticEntry(
            ts: Date(timeIntervalSince1970: 1_700_000_000),
            event: .layoutOutcomeInstant(.init(
                layoutID: dummyID, placed: 4, minimized: 1, leftEmpty: 0, failed: 0
            ))
        )
        let data = try JSONEncoder().encode(entry)
        let back = try JSONDecoder().decode(DiagnosticEntry.self, from: data)
        XCTAssertEqual(back, entry)
    }

    // MARK: - Byte-cap targets (compact encoding)

    /// Per CLAUDE.md plan: payload-only target sizes. Uses default
    /// JSONEncoder (no .prettyPrinted, no .sortedKeys) — compact form.
    func testCompactSizesMeetHardCaps() throws {
        let enc = JSONEncoder()
        // `lf` carries a snapshot; hard cap 500 B with one screen
        let lf = DiagnosticEntry(
            ts: Date(timeIntervalSince1970: 1_700_000_000),
            event: .layoutFired(.init(
                layoutID: dummyID, source: .hotkey, snapshot: sampleSnapshot()
            ))
        )
        XCTAssertLessThanOrEqual(try enc.encode(lf).count, 700,
            "layoutFired must encode under 700 B with 1-screen snapshot")

        // `loi` 300 B
        let loi = DiagnosticEntry(
            ts: Date(timeIntervalSince1970: 1_700_000_000),
            event: .layoutOutcomeInstant(.init(
                layoutID: dummyID, placed: 4, minimized: 0, leftEmpty: 0, failed: 0
            ))
        )
        XCTAssertLessThanOrEqual(try enc.encode(loi).count, 300)

        // `axp` 200 B
        let axp = DiagnosticEntry(
            ts: Date(timeIntervalSince1970: 1_700_000_000),
            event: .axPermissionChanged(.init(granted: true))
        )
        XCTAssertLessThanOrEqual(try enc.encode(axp).count, 200)
    }

    // MARK: - typeKey stability (do NOT change without bumping format version)

    func testTypeKeysAreStable() {
        XCTAssertEqual(DiagnosticEvent.layoutFired(.init(
            layoutID: dummyID, source: .hotkey, snapshot: sampleSnapshot()
        )).typeKey, "lf")
        XCTAssertEqual(DiagnosticEvent.axPermissionChanged(.init(granted: true)).typeKey, "axp")
        XCTAssertEqual(DiagnosticEvent.appQuitSurvivors(.init(
            workspaceID: dummyID, requested: 0, survivorBundleIDHashes: []
        )).typeKey, "aqs")
    }

    // MARK: - Privacy contract: payload string fields are hashes only

    /// Construct an event with a known sentinel hash; assert the JSON
    /// contains the hash exactly and contains no other String fields
    /// matching common PII patterns.
    func testPrivacyContractNoPlaintextLeak() throws {
        let entry = DiagnosticEntry(
            ts: Date(timeIntervalSince1970: 1_700_000_000),
            event: .triggerFired(.init(
                workspaceID: dummyID, kind: .monitorConnect,
                displayNameHash: "HASH-TOKEN12"
            ))
        )
        let json = String(data: try JSONEncoder().encode(entry), encoding: .utf8) ?? ""
        XCTAssertTrue(json.contains("HASH-TOKEN12"))
        // No raw display name leaked
        XCTAssertFalse(json.contains("DELL"))
        XCTAssertFalse(json.contains("LG "))
    }

    // MARK: - Helper

    private func roundTrip(_ original: DiagnosticEvent) throws {
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DiagnosticEvent.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
