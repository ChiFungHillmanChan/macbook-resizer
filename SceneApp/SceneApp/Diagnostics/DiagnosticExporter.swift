import AppKit
import SceneCore

/// Builds an opt-in diagnostic bundle (zip) for bug reports.
///
/// The flow:
///   1. Snapshot raw stores in memory (never mutates production data)
///   2. Sanitize via `ExportSanitizer` — every user-authored string
///      becomes a 11-char `DiagnosticHasher` token
///   3. Write `system-info.txt` containing `hashID = SHA256(salt)[0:8]`
///      — never the salt itself (R2-3)
///   4. Write `README.txt` explaining the bundle's privacy contract
///   5. Copy active `.jsonl` and rotated `.jsonl.gz` files into staging
///   6. Run `/usr/bin/ditto -c -k --sequesterRsrc <staging> <output>`
///   7. Atomically delete staging
///
/// The user picks the output URL via `NSSavePanel`. Caller can disable
/// the trigger UI via `controller.enabled == false`.
@MainActor
final class DiagnosticExporter {
    private let layoutStore: LayoutStore
    private let workspaceStore: WorkspaceStore
    private let settingsStore: SettingsStore
    private let controller: DiagnosticController
    private let processRunner: ProcessRunner

    enum Error: Swift.Error {
        case dittoFailed(exitStatus: Int32, stderr: String)
        case missingSourceDirectory
    }

    init(
        layoutStore: LayoutStore,
        workspaceStore: WorkspaceStore,
        settingsStore: SettingsStore,
        controller: DiagnosticController,
        processRunner: ProcessRunner = RealProcessRunner()
    ) {
        self.layoutStore = layoutStore
        self.workspaceStore = workspaceStore
        self.settingsStore = settingsStore
        self.controller = controller
        self.processRunner = processRunner
    }

    /// Default filename: `scene-diagnostics-YYYYMMDD-HHMMSS.zip`. The
    /// date is local-time so users picking it out of Downloads see a
    /// recognizable timestamp.
    static func defaultFilename(now: Date = Date()) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return "scene-diagnostics-\(f.string(from: now)).zip"
    }

    /// Builds the bundle and writes it to `outputURL`. Stages everything
    /// in a unique temp dir; cleans up on success and failure.
    func export(to outputURL: URL) async throws {
        let stagingDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("scene-diagnostics-\(UUID().uuidString)")
        let fm = FileManager.default
        try fm.createDirectory(at: stagingDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: stagingDir) }

        // Snapshot raw store data. Reads on the main actor are safe and
        // don't block the writer (which lives on its own actor).
        let layouts = layoutStore.layouts
        let workspaces = workspaceStore.workspaces
        let hasher = controller.hasher

        // Sanitize → DTOs (no PII)
        let sanitizedLayouts = ExportSanitizer.sanitize(layouts: layouts, hasher: hasher)
        let sanitizedWorkspaces = ExportSanitizer.sanitize(workspaces: workspaces, hasher: hasher)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(sanitizedLayouts).write(
            to: stagingDir.appendingPathComponent("layouts.json"), options: .atomic)
        try encoder.encode(sanitizedWorkspaces).write(
            to: stagingDir.appendingPathComponent("workspaces.json"), options: .atomic)
        // Settings have no PII (animation duration, drag-swap toggle, etc.) —
        // pass through verbatim.
        let settingsBlob: [String: Any] = [
            "animation": [
                "enabled": settingsStore.animation.enabled,
                "durationMs": settingsStore.animation.durationMs,
                "easing": String(describing: settingsStore.animation.easing),
            ] as [String: Any],
            "dragSwap": [
                "enabled": settingsStore.dragSwap.enabled,
                "distanceThresholdPt": settingsStore.dragSwap.distanceThresholdPt,
            ] as [String: Any],
        ]
        let settingsData = try JSONSerialization.data(
            withJSONObject: settingsBlob,
            options: [.prettyPrinted, .sortedKeys]
        )
        try settingsData.write(
            to: stagingDir.appendingPathComponent("settings.json"), options: .atomic)

        // Copy active jsonl + rotated gz files
        let diagFiles = (try? DiagnosticBudget.diagnosticFiles(in: controller.directory)) ?? []
        for file in diagFiles {
            let destination = stagingDir.appendingPathComponent(file.url.lastPathComponent)
            try? fm.copyItem(at: file.url, to: destination)
        }

        // Append the in-memory ring buffer for events that haven't yet
        // flushed to disk. Goes in a separate file to keep the on-disk
        // jsonl semantics intact.
        let recentEntries = controller.recentEntriesSnapshot()
        if !recentEntries.isEmpty {
            let entryEncoder = JSONEncoder()
            entryEncoder.dateEncodingStrategy = .iso8601
            var blob = Data()
            for entry in recentEntries {
                if let line = try? entryEncoder.encode(entry) {
                    blob.append(line)
                    blob.append(0x0A)
                }
            }
            try blob.write(
                to: stagingDir.appendingPathComponent("recent-events.jsonl"), options: .atomic)
        }

        // system-info.txt — hashID only, NOT salt (R2-3)
        let bundleVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "?"
        let buildVersion = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "?"
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let screenCount = NSScreen.screens.count
        let axGranted = AXPermission.forceRecheck()
        let info = """
        Scene Diagnostic Bundle
        =======================
        Scene version : \(bundleVersion) (build \(buildVersion))
        macOS         : \(osVersion)
        AX granted    : \(axGranted)
        Screens       : \(screenCount)
        Hash ID       : \(hasher.hashID())
        Generated at  : \(ISO8601DateFormatter().string(from: Date()))
        """
        try info.data(using: .utf8)?.write(
            to: stagingDir.appendingPathComponent("system-info.txt"), options: .atomic)

        // README.txt — privacy contract for whoever opens the bundle
        let readme = """
        Scene diagnostic bundle
        =======================
        This archive contains Scene's local event log plus configuration
        snapshots, sanitized for privacy:

          - All user-authored names (workspace names, layout names) are
            replaced with 11-character SHA256-prefix hashes.
          - All bundle IDs (apps to launch / quit / Focus shortcut names /
            calendar keywords / monitor display names) are hashed.
          - The hashing salt itself is NOT included. Only `hashID` is, so
            the recipient can confirm that hashes within this single bundle
            share one salt family — but cannot reverse hashes back to
            plaintext.
          - Window titles, file paths, and user input are never recorded.

        Files
        -----
          system-info.txt              Scene + macOS versions, screen count, hashID
          settings.json                Animation + drag-swap config (no PII)
          layouts.json                 Sanitized layouts
          workspaces.json              Sanitized workspaces
          events-YYYY-MM-DD.jsonl      Active diagnostic log (newline-delimited JSON)
          events-YYYY-MM-DD.jsonl.gz   Rotated diagnostic logs (gzip)
          recent-events.jsonl          In-memory tail (last ~200 events)
        """
        try readme.data(using: .utf8)?.write(
            to: stagingDir.appendingPathComponent("README.txt"), options: .atomic)

        // Atomic move target: ditto refuses to overwrite existing zip
        try? fm.removeItem(at: outputURL)

        // Run /usr/bin/ditto. Files land at zip root (no `--keepParent`).
        // No `--sequesterRsrc` either — our payload is plain JSON/text
        // with no extended attributes worth preserving, and the flag
        // would only add a noisy `__MACOSX/` folder.
        let result = try await processRunner.run(
            executable: URL(fileURLWithPath: "/usr/bin/ditto"),
            arguments: ["-c", "-k", stagingDir.path, outputURL.path]
        )
        guard result.exitStatus == 0 else {
            throw Error.dittoFailed(
                exitStatus: result.exitStatus,
                stderr: String(data: result.stderr, encoding: .utf8) ?? ""
            )
        }
    }
}
