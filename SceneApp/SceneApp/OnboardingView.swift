import AppKit
import SwiftUI
import SceneCore

struct OnboardingView: View {
    var onGrant: () -> Void
    @State private var showCopiedLabel: Bool = false

    /// Bundle ID matches PRODUCT_BUNDLE_IDENTIFIER in project.pbxproj. Hard-coded
    /// because the reset command must survive a broken AX permission state — no
    /// Bundle.main lookup gymnastics.
    private let resetCommand = "tccutil reset Accessibility com.hillman.SceneApp"

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
                onGrant()
            }
            .buttonStyle(.link)

            // The recovery hint is shown unconditionally (V0.5.4): users
            // upgrading from an ad-hoc-signed build (v0.4.3 or earlier) to
            // notarized v0.5.0+ get a stale TCC grant — the cdhash changed and
            // toggling Accessibility OFF/ON in System Settings doesn't refresh
            // the stored `csreq`. Previously this hint was gated on a failed
            // "Check again", but most users grant in System Settings and wait
            // for the 2s polling timer to pick it up — they never click Check
            // again, so they never saw the rescue command. Always-visible.
            Divider().padding(.vertical, 4)
            VStack(spacing: 10) {
                Text("onboarding.accessibility.still_not_detected.title")
                    .font(.callout)
                    .bold()
                Text("onboarding.accessibility.still_not_detected.body")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 420)

                HStack(spacing: 8) {
                    Text(resetCommand)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.secondary.opacity(0.12))
                        .cornerRadius(4)
                    Button(action: copyResetCommand) {
                        Text(showCopiedLabel
                             ? "onboarding.accessibility.command_copied"
                             : "onboarding.accessibility.copy_command")
                    }
                    .controlSize(.small)
                }

                Text("onboarding.accessibility.reset_command_hint")
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 420)

                Button("menu.quit") {
                    NSApplication.shared.terminate(nil)
                }
                .controlSize(.small)
            }
        }
        .padding(32)
        .frame(width: 500, height: 500)
    }

    private func copyResetCommand() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(resetCommand, forType: .string)
        withAnimation(.easeInOut(duration: 0.15)) {
            showCopiedLabel = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.15)) {
                showCopiedLabel = false
            }
        }
    }
}
