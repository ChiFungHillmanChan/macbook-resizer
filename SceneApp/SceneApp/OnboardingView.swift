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
            Text("onboarding.accessibility.title")
                .font(.title2)
                .bold()
            Text("onboarding.accessibility.body")
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
                .foregroundStyle(.secondary)
            Button("onboarding.accessibility.open_settings") {
                if let url = AXPermission.systemSettingsURL {
                    NSWorkspace.shared.open(url)
                }
            }
            .keyboardShortcut(.defaultAction)
            Button("onboarding.accessibility.check_again") {
                checkAttempts += 1
                onGrant()
            }
            .buttonStyle(.link)

            if checkAttempts >= 1 {
                Divider().padding(.vertical, 4)
                VStack(spacing: 8) {
                    Text("onboarding.accessibility.still_not_detected.title")
                        .font(.callout)
                        .bold()
                    Text("onboarding.accessibility.still_not_detected.body")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 380)
                    Button("menu.quit") {
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
