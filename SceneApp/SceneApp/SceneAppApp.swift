import SwiftUI
import SceneCore

@main
struct SceneAppEntry: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(
                workspaceStore: delegate.workspaceVM,
                layoutStore: delegate.layoutVM
            )
            .environmentObject(delegate.coordinator)
            .environmentObject(delegate)
            .environmentObject(delegate.updateChecker)
            .environmentObject(delegate.updateInstaller)
        } label: {
            MenuBarLabel(coordinator: delegate.coordinator)
        }
        .menuBarExtraStyle(.menu)
    }
}

/// Wraps the menu bar icon so it can observe `Coordinator.freeMode`
/// and swap to a "paused" glyph when Free Mode is active. The label
/// closure of `MenuBarExtra` does not automatically subscribe to
/// `@Published` changes from environment objects, so we observe the
/// coordinator directly via `@ObservedObject`.
private struct MenuBarLabel: View {
    @ObservedObject var coordinator: Coordinator

    var body: some View {
        Image(systemName: coordinator.freeMode ? "pause.rectangle" : "rectangle.3.group")
    }
}
