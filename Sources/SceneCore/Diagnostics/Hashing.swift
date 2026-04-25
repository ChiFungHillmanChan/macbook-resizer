import Foundation
import CryptoKit

/// Hashes user-supplied strings (workspace names, app bundle IDs, monitor
/// names, calendar keywords, focus shortcut names) into short, opaque,
/// salted tokens. Salt is held in RAM only — never serialized into JSONL,
/// never copied into export bundles. See `SaltStore` (M1) for persistence.
///
/// Two strings hash to the same token within a single salt domain (the
/// "enable-period"); switching the salt produces an entirely new family.
/// Devs receiving an export bundle can confirm "all hashes share one
/// family" via `hashID` (the salt's own hash), but cannot reverse the
/// salt to recover plaintext.
public struct DiagnosticHasher: Sendable {
    public let salt: Data
    public static let outputBytes = 8

    public init(salt: Data) {
        self.salt = salt
    }

    /// 11-character base64url-without-padding token (8 bytes of SHA256).
    public func hash(_ value: String) -> String {
        var hasher = SHA256()
        hasher.update(data: salt)
        hasher.update(data: Data(value.utf8))
        let digest = hasher.finalize()
        let prefix = Data(digest.prefix(Self.outputBytes))
        return Self.base64URL(prefix)
    }

    /// Stable, non-secret derivation of the salt itself. Goes into
    /// `system-info.txt` so devs can verify two events in the same export
    /// share a salt family without learning the salt.
    public func hashID() -> String {
        let digest = SHA256.hash(data: salt)
        return Self.base64URL(Data(digest.prefix(Self.outputBytes)))
    }

    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
