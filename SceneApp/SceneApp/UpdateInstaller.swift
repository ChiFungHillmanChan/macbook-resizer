import AppKit
import Combine
import Foundation
import os

/// V0.5.6: Sparkle-free in-app updater.
///
/// Flow:
///   1. Download the DMG asset to `~/Library/Caches/Scene/`.
///   2. `codesign -dv` the DMG and confirm `TeamIdentifier=22K6G3HH9G`.
///   3. Write a helper bash script to `/tmp/`, launch it detached via
///      `nohup`, then `NSApp.terminate(nil)`.
///   4. Helper waits for Scene's PID to exit, mounts the DMG, replaces
///      `/Applications/Scene.app` (or wherever Scene was installed) with
///      `ditto --noqtn` so the `com.apple.macl` xattr that anchors the TCC
///      Accessibility grant is preserved, unmounts, and `open`s the new app.
///
/// Why not Sparkle: zero-dependency posture, plus we already have the GitHub
/// release polling and the notarized DMG pipeline. The custom installer is
/// ~100 lines vs ~1MB of framework + appcast hosting.
///
/// Why TCC survives: macOS TCC binds the Accessibility grant to the binary's
/// **Designated Requirement** (`anchor apple generic and identifier
/// "com.hillman.SceneApp" and certificate ... and certificate leaf[subject.OU]
/// = "22K6G3HH9G"`). That requirement is stable across any release we sign
/// with the same Developer ID, so TCC accepts the new binary. `ditto`
/// preserves the `com.apple.macl` xattr (TCC's per-file pointer); the new
/// install's `com.apple.quarantine` xattr is stripped to avoid a Gatekeeper
/// re-prompt.
@MainActor
final class UpdateInstaller: ObservableObject {
    @Published private(set) var isInstalling = false
    @Published private(set) var statusMessage: String?
    @Published private(set) var lastError: String?

    private let log = Logger(subsystem: "com.scene.app", category: "update-installer")
    private let expectedTeamID = "22K6G3HH9G"

    /// Kicks off the full download → verify → install → quit flow. On
    /// success this function does not return — Scene quits before the helper
    /// finishes. On failure, `lastError` is populated.
    func install(dmgURL: URL, version: String) async {
        guard !isInstalling else { return }
        isInstalling = true
        defer { isInstalling = false }

        do {
            statusMessage = String(format: String(localized: "update.installer.downloading"), version)
            log.info("downloading \(dmgURL.absoluteString, privacy: .public)")
            let dmgPath = try await downloadDMG(from: dmgURL, version: version)

            statusMessage = String(localized: "update.installer.verifying")
            try verifyDMGSignature(dmgPath: dmgPath)

            statusMessage = String(localized: "update.installer.installing")
            try launchHelperScript(dmgPath: dmgPath)

            // Helper waits for our PID — quit Scene now so the helper can
            // proceed with the file replacement.
            log.info("install handoff complete; quitting Scene to let helper run")
            NSApp.terminate(nil)
        } catch {
            log.error("install failed: \(String(describing: error), privacy: .public)")
            lastError = String(describing: error)
            statusMessage = nil

            // Surface to the user via macOS notification — they triggered an
            // install and got nothing visible, so without this they'd assume
            // the menu item is broken.
            let alert = NSAlert()
            alert.messageText = String(localized: "update.installer.failed.title")
            alert.informativeText = lastError ?? ""
            alert.alertStyle = .warning
            alert.addButton(withTitle: String(localized: "common.ok"))
            alert.runModal()
        }
    }

    // MARK: - Download

    private func downloadDMG(from url: URL, version: String) async throws -> URL {
        let cacheDir = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Scene", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        let dest = cacheDir.appendingPathComponent("Scene-\(version).dmg")

        // Drop any stale cached download before re-fetching — version match
        // alone isn't proof of integrity if a previous attempt was killed
        // mid-write.
        try? FileManager.default.removeItem(at: dest)

        var request = URLRequest(url: url)
        request.timeoutInterval = 60
        let (tempURL, response) = try await URLSession.shared.download(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw NSError(
                domain: "UpdateInstaller", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Download failed (HTTP \(code))"]
            )
        }
        try FileManager.default.moveItem(at: tempURL, to: dest)
        return dest
    }

    // MARK: - Signature verification

    private func verifyDMGSignature(dmgPath: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["-dv", "--verbose=4", dmgPath.path]
        let stderr = Pipe()
        process.standardError = stderr
        process.standardOutput = Pipe()
        try process.run()
        process.waitUntilExit()
        let output = String(
            data: stderr.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""

        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "UpdateInstaller", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "codesign verification failed: \(output)"]
            )
        }
        guard output.contains("TeamIdentifier=\(expectedTeamID)") else {
            throw NSError(
                domain: "UpdateInstaller", code: 3,
                userInfo: [NSLocalizedDescriptionKey:
                    "DMG is not signed by Team ID \(expectedTeamID). Refusing to install."]
            )
        }
    }

    // MARK: - Helper script

    private func launchHelperScript(dmgPath: URL) throws {
        let scenePID = ProcessInfo.processInfo.processIdentifier
        // Resolve the actual install path from Bundle so the helper replaces
        // the right binary even if Scene was installed somewhere other than
        // /Applications (e.g., ~/Applications, or a non-standard Homebrew
        // prefix).
        let scenePath = Bundle.main.bundleURL.path
        let scriptPath = "/tmp/scene-update-\(UUID().uuidString).sh"
        let logPath = "/tmp/scene-update-\(scenePID).log"

        let script = """
        #!/bin/bash
        # Scene auto-update helper. Generated and launched by UpdateInstaller.
        set -uo pipefail
        DMG=\(escapeShell(dmgPath.path))
        SCENE_PID=\(scenePID)
        APP_DEST=\(escapeShell(scenePath))
        LOG=\(escapeShell(logPath))

        exec >>"$LOG" 2>&1
        echo ""
        echo "[$(date)] Scene update helper starting"
        echo "  DMG: $DMG"
        echo "  Target: $APP_DEST"
        echo "  Waiting on Scene PID $SCENE_PID..."

        # Wait up to 30s for Scene to quit cleanly. Don't force-kill — Scene's
        # applicationWillTerminate flushes UserDefaults + stops trigger watchers.
        for i in $(seq 1 60); do
            if ! ps -p $SCENE_PID > /dev/null 2>&1; then
                echo "  Scene exited after $((i / 2))s"
                break
            fi
            sleep 0.5
        done

        if ps -p $SCENE_PID > /dev/null 2>&1; then
            echo "ERROR: Scene did not exit within 30s — aborting install"
            exit 1
        fi

        # Mount the new DMG
        echo "Mounting DMG…"
        MOUNT_OUT=$(hdiutil attach "$DMG" -nobrowse -noverify -noautoopen)
        MOUNT=$(echo "$MOUNT_OUT" | grep '/Volumes/' | awk '{for(i=3;i<=NF;i++)printf "%s ",$i;print ""}' | sed 's/ *$//' | head -1)
        if [ -z "$MOUNT" ] || [ ! -d "$MOUNT/Scene.app" ]; then
            echo "ERROR: failed to mount DMG or Scene.app missing in mount"
            exit 1
        fi
        echo "  Mounted at: $MOUNT"

        # Backup the old install in case ditto fails partway. /tmp is a tmpfs
        # so this costs no real disk; cleaned up on success.
        BACKUP="/tmp/Scene.app.bak-$$"
        if [ -d "$APP_DEST" ]; then
            mv "$APP_DEST" "$BACKUP"
            echo "  Backed up old app to $BACKUP"
        fi

        # ditto preserves resource forks, ACLs, and crucially extended
        # attributes — including com.apple.macl, the TCC linkage that anchors
        # the Accessibility grant to this app. --noqtn strips the
        # com.apple.quarantine xattr that would otherwise trigger a Gatekeeper
        # "downloaded from internet" re-prompt on first launch.
        echo "Replacing app with ditto --noqtn…"
        if ! ditto --noqtn "$MOUNT/Scene.app" "$APP_DEST"; then
            echo "ERROR: ditto failed; rolling back"
            rm -rf "$APP_DEST"
            mv "$BACKUP" "$APP_DEST"
            hdiutil detach "$MOUNT" -force >/dev/null 2>&1 || true
            exit 1
        fi

        # Belt-and-suspenders: strip quarantine from the destination too, in
        # case ditto's --noqtn missed anything in nested resources.
        xattr -dr com.apple.quarantine "$APP_DEST" 2>/dev/null || true

        # Cleanup
        rm -rf "$BACKUP"
        hdiutil detach "$MOUNT" -force >/dev/null 2>&1 || true
        rm -f "$DMG"

        echo "Install complete. Launching new Scene…"
        # Ask LaunchServices to register the replaced bundle so the new
        # Bundle Identifier <-> path mapping is fresh before we open it.
        /System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -f "$APP_DEST" 2>/dev/null || true
        open -n "$APP_DEST"

        # Self-destruct
        echo "[$(date)] Helper done"
        rm -f "$0"
        """

        try script.write(toFile: scriptPath, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: 0o755)],
            ofItemAtPath: scriptPath
        )

        // Detach from Scene's process group via nohup so the helper survives
        // our termination. Process becomes a child of launchd after Scene
        // exits, which is the correct place to be parented during the
        // window where Scene.app on disk is briefly missing.
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/nohup")
        task.arguments = [scriptPath]
        task.standardInput = FileHandle.nullDevice
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        try task.run()
        // Deliberately do NOT waitUntilExit — let it run detached.
    }

    private func escapeShell(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
