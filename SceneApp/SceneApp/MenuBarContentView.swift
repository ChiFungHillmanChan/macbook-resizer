import SwiftUI
import SceneCore

struct MenuBarContentView: View {
    @EnvironmentObject var coordinator: Coordinator
    @EnvironmentObject var appDelegate: AppDelegate

    var body: some View {
        if coordinator.permissionGranted {
            grantedMenu
        } else {
            ungrantedMenu
        }
    }

    @ViewBuilder
    private var grantedMenu: some View {
        // Touch layoutListVersion so SwiftUI rebuilds when LayoutStore mutates.
        let _ = coordinator.layoutListVersion
        ForEach(coordinator.layoutStore.layouts) { layout in
            Button(label(for: layout)) {
                coordinator.applyLayout(layout)
            }
        }
        Divider()
        Button("Settings…") {
            appDelegate.openSettings()
        }
        .keyboardShortcut(",")
        Divider()
        Button("Quit Scene") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    @ViewBuilder
    private var ungrantedMenu: some View {
        Button("Grant Accessibility Access…") {
            coordinator.openOnboarding()
        }
        Divider()
        Button("Quit Scene") { NSApp.terminate(nil) }
    }

    private func label(for layout: CustomLayout) -> String {
        if let h = layout.hotkey {
            return "\(layout.name)\t\(h.displayString)"
        }
        return layout.name
    }
}
