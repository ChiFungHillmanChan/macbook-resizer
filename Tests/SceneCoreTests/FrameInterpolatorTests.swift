import XCTest
import CoreGraphics
@testable import SceneCore

final class FrameInterpolatorTests: XCTestCase {
    private let start = CGRect(x: 0, y: 0, width: 100, height: 100)
    private let target = CGRect(x: 200, y: 100, width: 400, height: 300)

    func testLinearAtZeroEqualsStart() {
        let r = FrameInterpolator.frame(start: start, target: target, easing: .linear, t: 0)
        XCTAssertEqual(r, start)
    }

    func testLinearAtOneEqualsTargetExactly() {
        let r = FrameInterpolator.frame(start: start, target: target, easing: .linear, t: 1)
        XCTAssertEqual(r, target)
    }

    func testLinearMidpoint() {
        let mid = FrameInterpolator.frame(start: start, target: target, easing: .linear, t: 0.5)
        XCTAssertEqual(mid.minX,   100, accuracy: 1e-9)
        XCTAssertEqual(mid.minY,    50, accuracy: 1e-9)
        XCTAssertEqual(mid.width,  250, accuracy: 1e-9)
        XCTAssertEqual(mid.height, 200, accuracy: 1e-9)
    }

    func testEaseOutAtEndpointsExact() {
        XCTAssertEqual(
            FrameInterpolator.frame(start: start, target: target, easing: .easeOut, t: 0),
            start
        )
        XCTAssertEqual(
            FrameInterpolator.frame(start: start, target: target, easing: .easeOut, t: 1),
            target
        )
    }

    func testEaseOutAheadOfLinearAtMid() {
        let linearMid = FrameInterpolator.frame(start: start, target: target, easing: .linear, t: 0.5)
        let easedMid  = FrameInterpolator.frame(start: start, target: target, easing: .easeOut, t: 0.5)
        XCTAssertGreaterThan(easedMid.minX, linearMid.minX)
    }

    func testSpringAtEndpointsExact() {
        XCTAssertEqual(
            FrameInterpolator.frame(start: start, target: target, easing: .spring, t: 0),
            start
        )
        XCTAssertEqual(
            FrameInterpolator.frame(start: start, target: target, easing: .spring, t: 1),
            target
        )
    }

    func testTOutsideZeroOneClamps() {
        XCTAssertEqual(
            FrameInterpolator.frame(start: start, target: target, easing: .easeOut, t: -0.5),
            start
        )
        XCTAssertEqual(
            FrameInterpolator.frame(start: start, target: target, easing: .easeOut, t: 1.5),
            target
        )
    }
}
