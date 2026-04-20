import AppKit
import Combine
import SceneCore

/// Launches and (gently) terminates apps by bundle ID.
/// Per §4.2 (V0.4 brainstorm decision): we send a cooperative Cmd-Q-equivalent
/// `terminate()`, wait 5 seconds, then surface a notification for any apps
/// still running. We DO NOT force-terminate — protecting unsaved work is
/// more important than guaranteeing a clean Workspace switch.
@MainActor
final class AppLauncher {
    struct QuitReport {
        let survivors: [NSRunningApplication]
    }

    /// Launches each bundle ID in parallel. Missing app → log + skip.
    func launch(bundleIDs: [String]) async {
        await withTaskGroup(of: Void.self) { group in
            for id in bundleIDs {
                group.addTask { @MainActor in
                    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else {
                        NSLog("[Scene] AppLauncher.launch: bundle ID not installed: \(id)")
                        return
                    }
                    let config = NSWorkspace.OpenConfiguration()
                    config.activates = false  // Scene keeps focus; user sees new windows unobtrusively
                    do {
                        try await NSWorkspace.shared.openApplication(at: url, configuration: config)
                    } catch {
                        NSLog("[Scene] AppLauncher.launch failed for \(id): \(error)")
                    }
                }
            }
        }
    }

    /// Gently terminates each bundle ID. Waits 5 seconds, then returns a list
    /// of apps that didn't quit (survivors). Caller surfaces a notification if
    /// survivors is non-empty. NEVER force-terminates (see spec §4.2).
    func quit(bundleIDs: [String]) async -> QuitReport {
        // Empty list means the caller has no apps to close — e.g., a default
        // seeded Workspace. Returning early avoids a gratuitous 5s delay that
        // would otherwise block the activation sequence and make a menu click
        // feel completely unresponsive.
        if bundleIDs.isEmpty { return QuitReport(survivors: []) }

        var toQuit: [NSRunningApplication] = []
        for id in bundleIDs {
            let apps = NSRunningApplication.runningApplications(withBundleIdentifier: id)
            for app in apps {
                app.terminate()  // cooperative; may present save dialog
                toQuit.append(app)
            }
        }

        // Grace period: 5 seconds for save dialogs / final cleanup.
        try? await Task.sleep(for: .seconds(5))

        let survivors = toQuit.filter { !$0.isTerminated }
        return QuitReport(survivors: survivors)
    }
}
