import Combine
import Foundation
import SceneCore
import os

/// Passive update nudge: polls the GitHub `releases/latest` endpoint at most
/// once every 24 hours per device and, when the remote tag is newer than the
/// running bundle version, publishes the pair so `MenuBarContentView` can
/// show an "Update available" menu item that opens the release page in the
/// browser.
///
/// Deliberately *not* Sparkle (and not silent auto-install):
/// - Keeping the user in the DMG install path preserves the same install
///   ritual across Homebrew and direct-download users — no divergence in
///   support flows.
/// - No signature verification here; Gatekeeper runs on the downloaded DMG
///   (notarized v0.5.0+, so no prompt).
@MainActor
final class UpdateChecker: ObservableObject {
    @Published private(set) var availableVersion: String?
    @Published private(set) var releasePageURL: URL?

    private let apiURL = URL(string:
        "https://api.github.com/repos/ChiFungHillmanChan/macbook-resizer/releases/latest"
    )!
    private let lastCheckKey = "com.scene.UpdateChecker.lastCheckedAt"
    private let minInterval: TimeInterval = 24 * 60 * 60

    private let log = Logger(subsystem: "com.scene.app", category: "update-checker")

    /// Kick off a non-blocking check. Safe to call on every launch — the
    /// 24-hour per-device debounce (persisted in `UserDefaults`) keeps us
    /// well inside GitHub's 60 req/hr unauthenticated rate limit even if
    /// the user relaunches many times per day.
    func checkIfDue() {
        let defaults = UserDefaults.standard
        if let last = defaults.object(forKey: lastCheckKey) as? Date,
           Date().timeIntervalSince(last) < minInterval {
            return
        }
        Task { [weak self] in await self?.performCheck() }
    }

    private func performCheck() async {
        do {
            var request = URLRequest(url: apiURL)
            request.timeoutInterval = 10
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }
            let release = try JSONDecoder().decode(Release.self, from: data)
            UserDefaults.standard.set(Date(), forKey: lastCheckKey)

            guard let bundleVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                  isVersionTag(release.tagName, newerThan: bundleVersion),
                  let url = URL(string: release.htmlURL)
            else { return }

            self.availableVersion = Self.normalizeTag(release.tagName)
            self.releasePageURL = url
        } catch {
            log.debug("update check failed: \(String(describing: error), privacy: .public)")
        }
    }

    private static func normalizeTag(_ tag: String) -> String {
        tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
    }

    private struct Release: Decodable {
        let tagName: String
        let htmlURL: String
        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
        }
    }
}
