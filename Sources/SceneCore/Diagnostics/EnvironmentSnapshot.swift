import Foundation
import CryptoKit

/// Canonical record of one screen's geometry. Integer fields (rounded to
/// points + scale*100) make signature comparisons deterministic across
/// tiny float drift in repeated NSScreen reads.
public struct ScreenRecord: Codable, Hashable, Sendable {
    public let id: UInt32       // CGDirectDisplayID (incl. Sidecar pseudo-IDs)
    public let x: Int
    public let y: Int
    public let w: Int
    public let h: Int
    public let vx: Int
    public let vy: Int
    public let vw: Int
    public let vh: Int
    public let scale100: Int    // backingScaleFactor * 100 (e.g. 200 = Retina)
    public let main: Bool

    public init(
        id: UInt32,
        x: Int, y: Int, w: Int, h: Int,
        vx: Int, vy: Int, vw: Int, vh: Int,
        scale100: Int,
        main: Bool
    ) {
        self.id = id
        self.x = x; self.y = y; self.w = w; self.h = h
        self.vx = vx; self.vy = vy; self.vw = vw; self.vh = vh
        self.scale100 = scale100
        self.main = main
    }
}

/// Environment context captured at log time. `sig` lets a single string
/// compare answer "did the arrangement change between event A and event
/// B?" without re-deriving from `screens`.
public struct EnvironmentSnapshot: Codable, Sendable, Equatable {
    public let ts: Date
    public let screens: [ScreenRecord]      // sorted by `id` ascending
    public let sig: String                  // 11-char base64url (8 SHA256 bytes)
    public let activeID: UInt32
    public let winCount: Int
    public let activeWS: UUID?
    public let secsSinceLastChange: TimeInterval?

    public init(
        ts: Date,
        screens: [ScreenRecord],
        activeID: UInt32,
        winCount: Int,
        activeWS: UUID?,
        secsSinceLastChange: TimeInterval?
    ) {
        let sorted = screens.sorted { $0.id < $1.id }
        self.ts = ts
        self.screens = sorted
        self.sig = Self.signature(of: sorted, activeID: activeID)
        self.activeID = activeID
        self.winCount = winCount
        self.activeWS = activeWS
        self.secsSinceLastChange = secsSinceLastChange
    }

    /// Deterministic SHA256 prefix over a canonical encoding of the
    /// (sorted screens + active display) tuple. Independent of the JSON
    /// encoder's key ordering.
    public static func signature(of sortedScreens: [ScreenRecord], activeID: UInt32) -> String {
        var hasher = SHA256()
        for s in sortedScreens {
            hasher.update(data: Data(String(s.id).utf8))
            hasher.update(data: Data("|".utf8))
            for v in [s.x, s.y, s.w, s.h, s.vx, s.vy, s.vw, s.vh, s.scale100] {
                hasher.update(data: Data(String(v).utf8))
                hasher.update(data: Data(",".utf8))
            }
            hasher.update(data: Data((s.main ? "M" : "_").utf8))
            hasher.update(data: Data(";".utf8))
        }
        hasher.update(data: Data("active=\(activeID)".utf8))
        let digest = hasher.finalize()
        return DiagnosticHasher.base64URL(Data(digest.prefix(8)))
    }
}
