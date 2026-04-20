import Foundation

/// Fail-safe semver-lite comparison used by the passive update nudge.
///
/// Both strings are stripped of a leading `v`, split on `.`, and each
/// component parsed as `Int`. Components that don't parse are dropped
/// via `compactMap`, so malformed inputs can't trigger a spurious
/// "newer" verdict — the function returns `false` (no nudge) in any
/// ambiguous case. A version with fewer components is padded with zeros
/// so `1.2` compares equal to `1.2.0`.
///
/// - Parameters:
///   - tag: Remote release tag, e.g. `"v0.4.3"` or `"0.4.3"`.
///   - bundle: Running bundle version from `CFBundleShortVersionString`,
///     e.g. `"0.4.2"`.
/// - Returns: `true` when `tag` represents a strictly newer version than
///   `bundle`. `false` when equal, older, or either side is unparseable.
public func isVersionTag(_ tag: String, newerThan bundle: String) -> Bool {
    let t = versionComponents(tag)
    let b = versionComponents(bundle)
    guard !t.isEmpty, !b.isEmpty else { return false }
    for i in 0..<max(t.count, b.count) {
        let ti = i < t.count ? t[i] : 0
        let bi = i < b.count ? b[i] : 0
        if ti != bi { return ti > bi }
    }
    return false
}

private func versionComponents(_ s: String) -> [Int] {
    let trimmed = s.hasPrefix("v") ? String(s.dropFirst()) : s
    return trimmed.split(separator: ".").compactMap { Int($0) }
}
