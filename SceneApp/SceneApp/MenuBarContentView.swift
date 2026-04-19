import SwiftUI
import SceneCore

struct MenuBarContentView: View {
    @EnvironmentObject var coordinator: Coordinator

    var body: some View {
        if coordinator.permissionGranted {
            grantedMenu
        } else {
            ungrantedMenu
        }
    }

    @ViewBuilder
    private var grantedMenu: some View {
        ForEach(Array(Layout.all.enumerated()), id: \.element.id) { (i, layout) in
            Button("\(layout.name)\t⌘⇧\(i+1)") {
                coordinator.applyLayout(layout.id)
            }
        }
        Divider()
        Button("Quit Scene") { NSApp.terminate(nil) }
    }

    @ViewBuilder
    private var ungrantedMenu: some View {
        Button("Grant Accessibility Access…") {
            coordinator.openOnboarding()
        }
        Divider()
        Button("Quit Scene") { NSApp.terminate(nil) }
    }
}
