import XCTest
@testable import SceneCore

final class MockWindowSmokeTests: XCTestCase {
    func testMockMatchesProtocol() throws {
        let w = MockWindow(id: 1, bundleID: "com.test", frame: .zero)
        try w.setFrame(CGRect(x: 10, y: 10, width: 100, height: 100))
        XCTAssertEqual(w.frame, CGRect(x: 10, y: 10, width: 100, height: 100))
        XCTAssertEqual(w.setFrameCallCount, 1)
        try w.minimize()
        XCTAssertTrue(w.isMinimized)
    }
}
