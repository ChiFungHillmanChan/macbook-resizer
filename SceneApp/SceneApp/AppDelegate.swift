import AppKit
import SwiftUI
import Combine
import SceneCore

final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    @Published private(set) var permissionGranted: Bool = false

    let layoutStore: LayoutStore
    let settingsStore: SettingsStore

    lazy var coordinator: Coordinator = Coordinator(
        layoutStore: layoutStore,
        settingsStore: settingsStore,
        onPermissionChange: { [weak self] granted in
            DispatchQueue.main.async { self?.permissionGranted = granted }
        }
    )

    /// Single shared instance — re-shown on subsequent "Settings…" clicks
    /// rather than recreated, so view-model state survives close/reopen.
    @MainActor
    private lazy var settingsWindow: SettingsWindowController = {
        SettingsWindowController(
            layoutVM: LayoutStoreViewModel(store: layoutStore),
            settingsVM: SettingsStoreViewModel(store: settingsStore)
        )
    }()

    override init() {
        let supportDir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Scene", isDirectory: true)
        let layoutsURL  = supportDir.appendingPathComponent("layouts.json")
        let settingsURL = supportDir.appendingPathComponent("settings.json")
        do {
            self.layoutStore = try LayoutStore(fileURL: layoutsURL)
            self.settingsStore = try SettingsStore(fileURL: settingsURL)
        } catch {
            fatalError("Scene: failed to initialize stores at \(supportDir.path): \(error)")
        }
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        coordinator.start()
    }

    @MainActor
    func openSettings() {
        settingsWindow.show()
    }
}
