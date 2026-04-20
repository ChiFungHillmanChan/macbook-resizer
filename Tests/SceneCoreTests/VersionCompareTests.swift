import XCTest
@testable import SceneCore

final class VersionCompareTests: XCTestCase {
    // MARK: - Positive cases (tag IS newer)

    func testPatchBump() {
        XCTAssertTrue(isVersionTag("0.4.3", newerThan: "0.4.2"))
    }

    func testMinorBump() {
        XCTAssertTrue(isVersionTag("0.5.0", newerThan: "0.4.9"))
    }

    func testMajorBump() {
        XCTAssertTrue(isVersionTag("1.0.0", newerThan: "0.99.99"))
    }

    func testTagWithVPrefix() {
        XCTAssertTrue(isVersionTag("v0.4.3", newerThan: "0.4.2"))
    }

    func testBundleWithVPrefix() {
        XCTAssertTrue(isVersionTag("0.4.3", newerThan: "v0.4.2"))
    }

    func testTagHasMoreComponents() {
        // `"0.4.2.1"` vs `"0.4.2"` — the 4th component makes the tag newer.
        XCTAssertTrue(isVersionTag("0.4.2.1", newerThan: "0.4.2"))
    }

    // MARK: - Negative cases (tag NOT newer)

    func testSameVersion() {
        XCTAssertFalse(isVersionTag("0.4.2", newerThan: "0.4.2"))
    }

    func testSameVersionWithMixedPrefix() {
        XCTAssertFalse(isVersionTag("v0.4.2", newerThan: "0.4.2"))
    }

    func testOlderPatch() {
        XCTAssertFalse(isVersionTag("0.4.1", newerThan: "0.4.2"))
    }

    func testOlderMinor() {
        XCTAssertFalse(isVersionTag("0.3.99", newerThan: "0.4.0"))
    }

    func testOlderMajor() {
        XCTAssertFalse(isVersionTag("0.99.0", newerThan: "1.0.0"))
    }

    func testShorterBundleTreatedAsZeroPadded() {
        // `"1.2"` is equivalent to `"1.2.0"`; neither is newer than the other.
        XCTAssertFalse(isVersionTag("1.2", newerThan: "1.2.0"))
        XCTAssertFalse(isVersionTag("1.2.0", newerThan: "1.2"))
    }

    func testTagHasMoreTrailingZeros() {
        // Extra trailing zeros are semantically equal.
        XCTAssertFalse(isVersionTag("0.4.2.0", newerThan: "0.4.2"))
        XCTAssertFalse(isVersionTag("0.4.2", newerThan: "0.4.2.0"))
    }

    // MARK: - Fail-safe on malformed input

    func testUnparseableTagReturnsFalse() {
        // Pre-release suffix like `"0.4.3-beta"` parses as `[0, 4]` (the
        // `"3-beta"` component drops out). That collapses to `0.4.0` which
        // is NOT newer than `0.4.2` — desired: no spurious nudge.
        XCTAssertFalse(isVersionTag("0.4.3-beta", newerThan: "0.4.2"))
    }

    func testEmptyTagReturnsFalse() {
        XCTAssertFalse(isVersionTag("", newerThan: "0.4.2"))
    }

    func testEmptyBundleReturnsFalse() {
        XCTAssertFalse(isVersionTag("0.4.3", newerThan: ""))
    }

    func testBothEmptyReturnsFalse() {
        XCTAssertFalse(isVersionTag("", newerThan: ""))
    }

    func testGarbageReturnsFalse() {
        XCTAssertFalse(isVersionTag("not.a.version", newerThan: "0.4.2"))
        XCTAssertFalse(isVersionTag("0.4.2", newerThan: "garbage"))
    }

    func testJustVPrefixReturnsFalse() {
        XCTAssertFalse(isVersionTag("v", newerThan: "0.4.2"))
    }
}
