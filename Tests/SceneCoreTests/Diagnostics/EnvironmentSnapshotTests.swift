import XCTest
@testable import SceneCore

final class EnvironmentSnapshotTests: XCTestCase {
    private func screen(
        id: UInt32 = 1,
        x: Int = 0, y: Int = 0, w: Int = 1920, h: Int = 1080,
        scale100: Int = 200,
        main: Bool = true
    ) -> ScreenRecord {
        ScreenRecord(
            id: id, x: x, y: y, w: w, h: h,
            vx: x, vy: y + 25, vw: w, vh: h - 25,
            scale100: scale100, main: main
        )
    }

    func testSignatureDeterministic() {
        let s1 = EnvironmentSnapshot(
            ts: Date(timeIntervalSince1970: 0),
            screens: [screen(id: 1), screen(id: 2, x: 1920, w: 2560, scale100: 100, main: false)],
            activeID: 1, winCount: 0, activeWS: nil, secsSinceLastChange: nil
        )
        let s2 = EnvironmentSnapshot(
            ts: Date(timeIntervalSince1970: 999),
            screens: [screen(id: 2, x: 1920, w: 2560, scale100: 100, main: false), screen(id: 1)],
            activeID: 1, winCount: 0, activeWS: nil, secsSinceLastChange: nil
        )
        XCTAssertEqual(s1.sig, s2.sig)
    }

    func testSignatureChangesOnResolutionChange() {
        let s1 = EnvironmentSnapshot(
            ts: Date(), screens: [screen(w: 1920, h: 1080)],
            activeID: 1, winCount: 0, activeWS: nil, secsSinceLastChange: nil
        )
        let s2 = EnvironmentSnapshot(
            ts: Date(), screens: [screen(w: 2560, h: 1440)],
            activeID: 1, winCount: 0, activeWS: nil, secsSinceLastChange: nil
        )
        XCTAssertNotEqual(s1.sig, s2.sig)
    }

    func testSignatureChangesOnSidecarReconnectAtDifferentScale() {
        let normal = EnvironmentSnapshot(
            ts: Date(),
            screens: [screen(id: 1), screen(id: 2, x: 1920, scale100: 200)],
            activeID: 1, winCount: 0, activeWS: nil, secsSinceLastChange: nil
        )
        let sidecar = EnvironmentSnapshot(
            ts: Date(),
            screens: [screen(id: 1), screen(id: 2, x: 1920, scale100: 100)],
            activeID: 1, winCount: 0, activeWS: nil, secsSinceLastChange: nil
        )
        XCTAssertNotEqual(normal.sig, sidecar.sig)
    }

    func testSignatureChangesOnMainDisplayChange() {
        let a = EnvironmentSnapshot(
            ts: Date(),
            screens: [screen(id: 1, main: true), screen(id: 2, x: 1920, main: false)],
            activeID: 1, winCount: 0, activeWS: nil, secsSinceLastChange: nil
        )
        let b = EnvironmentSnapshot(
            ts: Date(),
            screens: [screen(id: 1, main: false), screen(id: 2, x: 1920, main: true)],
            activeID: 1, winCount: 0, activeWS: nil, secsSinceLastChange: nil
        )
        XCTAssertNotEqual(a.sig, b.sig)
    }

    func testSignatureChangesOnActiveDisplayChange() {
        let a = EnvironmentSnapshot(
            ts: Date(),
            screens: [screen(id: 1), screen(id: 2, x: 1920)],
            activeID: 1, winCount: 0, activeWS: nil, secsSinceLastChange: nil
        )
        let b = EnvironmentSnapshot(
            ts: Date(),
            screens: [screen(id: 1), screen(id: 2, x: 1920)],
            activeID: 2, winCount: 0, activeWS: nil, secsSinceLastChange: nil
        )
        XCTAssertNotEqual(a.sig, b.sig)
    }

    func testScreensAlwaysSortedByID() {
        let snap = EnvironmentSnapshot(
            ts: Date(),
            screens: [
                screen(id: 9), screen(id: 3), screen(id: 7), screen(id: 1),
            ],
            activeID: 3, winCount: 0, activeWS: nil, secsSinceLastChange: nil
        )
        XCTAssertEqual(snap.screens.map(\.id), [1, 3, 7, 9])
    }

    func testScreenRecordCodableRoundTrip() throws {
        let r = screen(id: 42, x: 100, y: 200, w: 1234, h: 567, scale100: 175, main: false)
        let data = try JSONEncoder().encode(r)
        let back = try JSONDecoder().decode(ScreenRecord.self, from: data)
        XCTAssertEqual(back, r)
    }

    func testEnvironmentSnapshotCodableRoundTrip() throws {
        let snap = EnvironmentSnapshot(
            ts: Date(timeIntervalSince1970: 1_000_000),
            screens: [screen(id: 1), screen(id: 2, x: 1920, w: 2560)],
            activeID: 1, winCount: 4,
            activeWS: UUID(uuidString: "DEADBEEF-1234-5678-90AB-CDEF12345678"),
            secsSinceLastChange: 3.14
        )
        let data = try JSONEncoder().encode(snap)
        let back = try JSONDecoder().decode(EnvironmentSnapshot.self, from: data)
        XCTAssertEqual(back.activeID, snap.activeID)
        XCTAssertEqual(back.winCount, snap.winCount)
        XCTAssertEqual(back.activeWS, snap.activeWS)
        XCTAssertEqual(back.screens, snap.screens)
        // Decoding should reconstruct sig from screens; equal up to encoder fidelity
        XCTAssertEqual(back.sig, snap.sig)
    }
}
