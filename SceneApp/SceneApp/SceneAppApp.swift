import SwiftUI
import SceneCore

@main
struct SceneAppEntry: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        MenuBarExtra("Scene", systemImage: "rectangle.3.group") {
            MenuBarContentView(
                workspaceStore: delegate.workspaceVM,
                layoutStore: delegate.layoutVM
            )
            .environmentObject(delegate.coordinator)
            .environmentObject(delegate)
        }
        .menuBarExtraStyle(.menu)
    }
}
