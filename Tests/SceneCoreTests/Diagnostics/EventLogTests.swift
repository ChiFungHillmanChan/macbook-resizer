import XCTest
@testable import SceneCore

final class EventLogTests: XCTestCase {
    private func entry(_ secondsSinceEpoch: TimeInterval) -> DiagnosticEntry {
        DiagnosticEntry(
            ts: Date(timeIntervalSince1970: secondsSinceEpoch),
            event: .axPermissionChanged(.init(granted: true))
        )
    }

    func testEmptyLogHasNoEntries() {
        let log = EventLog(capacity: 5)
        XCTAssertEqual(log.count, 0)
        XCTAssertEqual(log.snapshot(), [])
    }

    func testAppendUnderCapacityKeepsAll() {
        let log = EventLog(capacity: 5)
        for i in 0..<3 { log.append(entry(Double(i))) }
        let snap = log.snapshot()
        XCTAssertEqual(snap.count, 3)
        XCTAssertEqual(snap.map(\.ts.timeIntervalSince1970), [0, 1, 2])
    }

    func testAppendOverCapacityEvictsOldest() {
        let log = EventLog(capacity: 3)
        for i in 0..<5 { log.append(entry(Double(i))) }
        let snap = log.snapshot()
        XCTAssertEqual(snap.count, 3)
        XCTAssertEqual(snap.map(\.ts.timeIntervalSince1970), [2, 3, 4])
    }

    func test200CapacityHonored() {
        let log = EventLog()  // default 200
        XCTAssertEqual(log.maxCapacity, 200)
        for i in 0..<500 { log.append(entry(Double(i))) }
        XCTAssertEqual(log.count, 200)
        let snap = log.snapshot()
        XCTAssertEqual(snap.first?.ts.timeIntervalSince1970, 300)
        XCTAssertEqual(snap.last?.ts.timeIntervalSince1970, 499)
    }

    func testObserverFiresPerAppend() {
        let log = EventLog(capacity: 5)
        var seen: [TimeInterval] = []
        let token = log.onAppend { e in seen.append(e.ts.timeIntervalSince1970) }
        for i in 0..<3 { log.append(entry(Double(i))) }
        XCTAssertEqual(seen, [0, 1, 2])
        token.cancel()
    }

    func testObserverCancelStopsCallbacks() {
        let log = EventLog(capacity: 5)
        var count = 0
        let token = log.onAppend { _ in count += 1 }
        log.append(entry(0))
        token.cancel()
        log.append(entry(1))
        XCTAssertEqual(count, 1)
    }

    func testConcurrentAppendsAllRecorded() {
        let log = EventLog(capacity: 10_000)
        let group = DispatchGroup()
        for thread in 0..<10 {
            group.enter()
            DispatchQueue.global().async {
                for i in 0..<100 {
                    log.append(self.entry(Double(thread * 100 + i)))
                }
                group.leave()
            }
        }
        group.wait()
        XCTAssertEqual(log.count, 1000)
    }
}
