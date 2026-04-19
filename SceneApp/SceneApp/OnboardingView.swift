import SwiftUI
import SceneCore

struct OnboardingView: View {
    var onGrant: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.3.group")
                .font(.system(size: 48))
            Text("Scene needs Accessibility access")
                .font(.title2)
                .bold()
            Text("To resize and rearrange your windows, Scene needs permission to control other apps.\n\nClick below to open System Settings, then enable Scene under Privacy & Security → Accessibility.")
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
                .foregroundStyle(.secondary)
            Button("Open System Settings") {
                if let url = AXPermission.systemSettingsURL {
                    NSWorkspace.shared.open(url)
                }
            }
            .keyboardShortcut(.defaultAction)
            Button("Check again") { onGrant() }
                .buttonStyle(.link)
        }
        .padding(32)
        .frame(width: 460, height: 340)
    }
}
