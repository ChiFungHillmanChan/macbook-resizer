import XCTest
@testable import SceneCore

/// Covers the NS↔AX vertical-flip helper. These are pure math tests — no real
/// displays required — so multi-monitor arrangements that are otherwise
/// impossible to reproduce in CI can still be pinned down here.
final class DisplayCoordinatesTests: XCTestCase {
    // MARK: - single-display (primary only)

    /// On the primary, a rect pinned to `y=0` (NS bottom) flips to `y=primary-h`
    /// (AX bottom edge) — and vice versa for a top-pinned rect.
    func testPrimaryFullHeightRectFlipsIdentically() {
        let primaryH: CGFloat = 800
        let ns = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let ax = DisplayCoordinates.nsToAX(ns, primaryHeight: primaryH)
        XCTAssertEqual(ax, CGRect(x: 0, y: 0, width: 1000, height: 800))
    }

    func testPrimaryTopHalfSlotFlipsToTop() {
        // "top half" in a template is rect.minY=0 height=0.5.
        // absoluteRect against a primary visibleFrame (0,0,W,H):
        //   NS (0, 0, W, H/2) — in NS coords, y=0 is the bottom of the screen,
        //   so this NS rect physically occupies the BOTTOM half.
        // After flip it should land at AX (0, H/2, W, H/2) — physically the
        // BOTTOM half too, but expressed as "H/2 pixels down from top". ✓
        let primaryH: CGFloat = 800
        let nsBottomHalf = CGRect(x: 0, y: 0, width: 1000, height: 400)
        let ax = DisplayCoordinates.nsToAX(nsBottomHalf, primaryHeight: primaryH)
        XCTAssertEqual(ax, CGRect(x: 0, y: 400, width: 1000, height: 400))
    }

    func testPrimaryBottomHalfSlotFlipsToBottom() {
        // Template's rect.minY=0.5 → NS rect at (0, H/2, W, H/2).
        // In NS, y=H/2 is middle of screen, extending up to y=H — physically
        // the TOP half. Flips to AX (0, 0, W, H/2) — top half in AX too. ✓
        let primaryH: CGFloat = 800
        let nsTopHalf = CGRect(x: 0, y: 400, width: 1000, height: 400)
        let ax = DisplayCoordinates.nsToAX(nsTopHalf, primaryHeight: primaryH)
        XCTAssertEqual(ax, CGRect(x: 0, y: 0, width: 1000, height: 400))
    }

    // MARK: - secondary display arrangements

    /// External primary (1000×800), MacBook secondary (800×600) placed ABOVE
    /// the external, tops floating. NS frame of MacBook: (0, 800, 800, 600).
    /// In AX, "above primary" means negative y: (0, -600, 800, 600).
    func testSecondaryAbovePrimary() {
        let primaryH: CGFloat = 800
        let nsFullSlot = CGRect(x: 0, y: 800, width: 800, height: 600)
        let ax = DisplayCoordinates.nsToAX(nsFullSlot, primaryHeight: primaryH)
        XCTAssertEqual(ax, CGRect(x: 0, y: -600, width: 800, height: 600))
    }

    /// External primary, MacBook secondary placed BELOW external.
    /// NS: (0, -600, 800, 600). AX: (0, 800, 800, 600).
    func testSecondaryBelowPrimary() {
        let primaryH: CGFloat = 800
        let nsFullSlot = CGRect(x: 0, y: -600, width: 800, height: 600)
        let ax = DisplayCoordinates.nsToAX(nsFullSlot, primaryHeight: primaryH)
        XCTAssertEqual(ax, CGRect(x: 0, y: 800, width: 800, height: 600))
    }

    /// External primary (1440 tall), MacBook secondary (1117 tall) placed to
    /// the RIGHT, physically top-aligned. Tops share the same physical height,
    /// so in NS the MacBook sits at y = H_ext - H_mbp = 323. In AX both tops
    /// are at y = 0.
    ///
    /// THIS IS THE BUG SCENARIO: passing the NS frame `(1440, 323, 1512, 1117)`
    /// verbatim to AX would land the window at AX y=323 — 323 px below the
    /// MacBook's actual top — producing the "window stuck in the bottom
    /// portion" symptom from the screenshot.
    func testSecondaryRightTopAligned() {
        let primaryH: CGFloat = 1440
        let nsFullSlot = CGRect(x: 1440, y: 323, width: 1512, height: 1117)
        let ax = DisplayCoordinates.nsToAX(nsFullSlot, primaryHeight: primaryH)
        XCTAssertEqual(ax, CGRect(x: 1440, y: 0, width: 1512, height: 1117))
    }

    /// Same two displays, bottom-aligned. NS y=0 for MacBook. AX y=323
    /// (MacBook's top sits 323 px below external's top).
    func testSecondaryRightBottomAligned() {
        let primaryH: CGFloat = 1440
        let nsFullSlot = CGRect(x: 1440, y: 0, width: 1512, height: 1117)
        let ax = DisplayCoordinates.nsToAX(nsFullSlot, primaryHeight: primaryH)
        XCTAssertEqual(ax, CGRect(x: 1440, y: 323, width: 1512, height: 1117))
    }

    // MARK: - half-slot within a secondary (the actual user scenario)

    /// Halves layout (left pane) on a MacBook secondary, top-aligned to right
    /// of primary 1440×H external. Template slot (0, 0, 0.5, 1) against
    /// MacBook visibleFrame (1440, 323, 1512, 1117) gives NS (1440, 323, 756,
    /// 1117). Flipped, the window should land at AX (1440, 0, 756, 1117) —
    /// left half of MacBook, full height. Without the flip it lands at AX
    /// (1440, 323, 756, 1117), stuck in the bottom ~70% of the MacBook, which
    /// is exactly the reported symptom.
    func testLeftHalfSlotOnSecondaryTopAligned() {
        let primaryH: CGFloat = 1440
        let leftHalfNS = CGRect(x: 1440, y: 323, width: 756, height: 1117)
        let ax = DisplayCoordinates.nsToAX(leftHalfNS, primaryHeight: primaryH)
        XCTAssertEqual(ax, CGRect(x: 1440, y: 0, width: 756, height: 1117))
    }

    // MARK: - inverse + x-axis invariants

    func testAXToNSIsInverseOfNSToAX() {
        let primaryH: CGFloat = 1440
        let original = CGRect(x: 1440, y: 323, width: 756, height: 1117)
        let roundTripped = DisplayCoordinates.axToNS(
            DisplayCoordinates.nsToAX(original, primaryHeight: primaryH),
            primaryHeight: primaryH
        )
        XCTAssertEqual(roundTripped, original)
    }

    func testXAxisIsNeverTouched() {
        let primaryH: CGFloat = 1000
        let ns = CGRect(x: 123.5, y: 456, width: 789, height: 321)
        let ax = DisplayCoordinates.nsToAX(ns, primaryHeight: primaryH)
        XCTAssertEqual(ax.origin.x, ns.origin.x)
        XCTAssertEqual(ax.width, ns.width)
        XCTAssertEqual(ax.height, ns.height)
    }

    // MARK: - point variants

    /// AX point on a secondary display ABOVE primary has negative y. Flipping
    /// with the primary-height pivot should land it inside the secondary's
    /// NS frame (which has minY >= primaryHeight). This is exactly what
    /// `AXWindowEnumerator` needs to correctly filter windows on a
    /// secondary-above arrangement — the previous code used the target
    /// screen's own `frame.maxY` as pivot, which silently dropped windows.
    func testAXPointAbovePrimaryFlipsIntoSecondaryVisibleFrame() {
        let primaryH: CGFloat = 800
        // Window center on a secondary (600 tall) arranged above primary,
        // physically centered vertically on that secondary: AX y = -300.
        let ax = CGPoint(x: 500, y: -300)
        let ns = DisplayCoordinates.axToNS(ax, primaryHeight: primaryH)
        XCTAssertEqual(ns, CGPoint(x: 500, y: 1100))
    }

    func testPointFlipIsItsOwnInverse() {
        let primaryH: CGFloat = 1440
        let ax = CGPoint(x: 1440, y: 558)
        let roundTrip = DisplayCoordinates.nsToAX(
            DisplayCoordinates.axToNS(ax, primaryHeight: primaryH),
            primaryHeight: primaryH
        )
        XCTAssertEqual(roundTrip, ax)
    }

    func testZeroPrimaryHeightProducesNegatedY() {
        // Defensive: if NSScreen.screens is empty (shouldn't happen on a real
        // Mac), the helper returns primaryHeight=0. Verify the math still
        // degrades predictably — flip around origin.
        let ns = CGRect(x: 0, y: 100, width: 50, height: 50)
        let ax = DisplayCoordinates.nsToAX(ns, primaryHeight: 0)
        XCTAssertEqual(ax, CGRect(x: 0, y: -150, width: 50, height: 50))
    }
}
