import SwiftUI

/// Content view for the one-time welcome window shown on first install (after
/// AX permission is granted). See
/// `docs/superpowers/specs/2026-04-21-first-launch-welcome-design.md` for the
/// full design.
///
/// Both closures are injected by `FirstLaunchWindowController`. "Got it" is the
/// default action (Enter key); "Open Settings" is visually primary to draw
/// first-time users toward the Workspaces tab.
struct FirstLaunchView: View {
    var onDismiss: () -> Void
    var onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("welcome.title")
                .font(.title2)
                .bold()

            Text("welcome.body")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 420)

            MenuBarIllustration()

            HStack(spacing: 12) {
                Button("welcome.button.got_it") { onDismiss() }
                    .keyboardShortcut(.defaultAction)

                Button("welcome.button.open_settings") { onOpenSettings() }
                    .buttonStyle(.borderedProminent)
            }
            .padding(.top, 4)
        }
        .padding(32)
        .frame(width: 560, height: 420)
    }
}

#Preview {
    FirstLaunchView(onDismiss: {}, onOpenSettings: {})
}
