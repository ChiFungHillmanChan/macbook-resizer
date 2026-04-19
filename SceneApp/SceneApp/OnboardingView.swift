import AppKit
import SwiftUI
import SceneCore

struct OnboardingView: View {
    var onGrant: () -> Void
    @State private var checkAttempts: Int = 0

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
            Button("Check again") {
                checkAttempts += 1
                onGrant()
            }
            .buttonStyle(.link)

            if checkAttempts >= 2 {
                Divider().padding(.vertical, 4)
                VStack(spacing: 8) {
                    Text("Still not detected?")
                        .font(.callout)
                        .bold()
                    Text("macOS sometimes needs Scene to relaunch after the toggle. Try quitting and reopening.")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 380)
                    Button("Quit Scene") {
                        NSApplication.shared.terminate(nil)
                    }
                    .controlSize(.small)
                }
            }
        }
        .padding(32)
        .frame(width: 460, height: 380)
    }
}
