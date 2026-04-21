import SwiftUI

/// Static SwiftUI illustration of a Mac menu bar with the Scene icon highlighted
/// on the right side and an animated arrow pointing up at it. Used by
/// `FirstLaunchView` to show new users where to look.
///
/// No image assets — everything is native SwiftUI, so it renders identically on
/// every display regardless of resolution.
struct MenuBarIllustration: View {
    @State private var arrowOffset: CGFloat = 0
    @State private var ringOpacity: Double = 1.0

    var body: some View {
        VStack(spacing: 8) {
            menuBarMock
            arrowAndCaption
        }
        .frame(width: 460, height: 120)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                arrowOffset = -4
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                ringOpacity = 0.6
            }
        }
    }

    private var menuBarMock: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Material.bar)
                .frame(height: 32)
                .shadow(color: .black.opacity(0.1), radius: 1, y: 1)

            HStack(spacing: 12) {
                // Left cluster: "Scene" bold + dimmed menu titles
                HStack(spacing: 10) {
                    Text("Scene")
                        .font(.system(size: 11, weight: .semibold))
                    Text("File")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text("Edit")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text("Window")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Right cluster: fake system status items + highlighted Scene icon
                HStack(spacing: 10) {
                    Image(systemName: "wifi")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Image(systemName: "battery.100")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text("Tue 3:42 PM")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    sceneStatusIcon
                }
            }
            .padding(.horizontal, 12)
        }
    }

    private var sceneStatusIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(Color.accentColor, lineWidth: 1.5)
                .opacity(ringOpacity)
                .frame(width: 22, height: 22)

            Image(systemName: "rectangle.3.group.fill")
                .font(.system(size: 12))
                .foregroundStyle(.primary)
        }
    }

    private var arrowAndCaption: some View {
        VStack(spacing: 2) {
            Image(systemName: "arrow.up")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.accentColor)
            Text("welcome.illustration.caption")
                .font(.caption)
                .foregroundStyle(Color.accentColor)
        }
        .offset(y: arrowOffset)
        // Align horizontally with the Scene icon in the right cluster. The icon
        // sits near the right edge; 460pt frame - ~22pt icon center - 12pt pad.
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.trailing, 20)
    }
}

#Preview {
    MenuBarIllustration()
        .padding()
        .frame(width: 520, height: 160)
}
