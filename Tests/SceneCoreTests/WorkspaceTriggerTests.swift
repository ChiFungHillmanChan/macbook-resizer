import XCTest
@testable import SceneCore

final class WorkspaceTriggerTests: XCTestCase {
    // MARK: - Round-trip each of 5 cases

    func testManualRoundTrip() throws {
        let original: WorkspaceTrigger = .manual
        let decoded = try roundTrip(original)
        XCTAssertEqual(decoded, original)
    }

    func testMonitorConnectRoundTrip() throws {
        let original: WorkspaceTrigger = .monitorConnect(displayName: "DELL U2723QE")
        let decoded = try roundTrip(original)
        XCTAssertEqual(decoded, original)
    }

    func testMonitorDisconnectRoundTrip() throws {
        let original: WorkspaceTrigger = .monitorDisconnect(displayName: "LG 34WK95U")
        let decoded = try roundTrip(original)
        XCTAssertEqual(decoded, original)
    }

    func testTimeOfDayRoundTrip() throws {
        let original: WorkspaceTrigger = .timeOfDay(
            weekdayMask: .weekdays, hour: 9, minute: 30
        )
        let decoded = try roundTrip(original)
        XCTAssertEqual(decoded, original)
    }

    func testCalendarEventRoundTrip() throws {
        let original: WorkspaceTrigger = .calendarEvent(keywordContains: "Standup")
        let decoded = try roundTrip(original)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - WeekdayMask

    func testWeekdayMaskWeekdays() {
        let m: WorkspaceTrigger.WeekdayMask = .weekdays
        XCTAssertTrue(m.contains(.monday))
        XCTAssertTrue(m.contains(.friday))
        XCTAssertFalse(m.contains(.saturday))
    }

    func testWeekdayMaskAll() {
        let m: WorkspaceTrigger.WeekdayMask = .all
        XCTAssertTrue(m.contains(.sunday))
        XCTAssertTrue(m.contains(.monday))
        XCTAssertEqual(m.rawValue, 127)
    }

    func testWeekdayMaskCodableRoundTrip() throws {
        let original: WorkspaceTrigger.WeekdayMask = [.monday, .wednesday, .friday]
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WorkspaceTrigger.WeekdayMask.self, from: encoded)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Helper

    private func roundTrip(_ trigger: WorkspaceTrigger) throws -> WorkspaceTrigger {
        let encoded = try JSONEncoder().encode(trigger)
        return try JSONDecoder().decode(WorkspaceTrigger.self, from: encoded)
    }
}
