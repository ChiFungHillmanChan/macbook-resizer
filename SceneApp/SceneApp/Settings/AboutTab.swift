import SwiftUI

/// "About Scene" tab — version + project link + re-open welcome screen action.
struct AboutTab: View {
    var reopenWelcome: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("about.app_name")
                .font(.largeTitle)
                .bold()
            Text("about.version")
                .foregroundStyle(.secondary)
            Link(
                "github.com/ChiFungHillmanChan/macbook-resizer",
                destination: URL(string: "https://github.com/ChiFungHillmanChan/macbook-resizer")!
            )

            Divider()
                .padding(.vertical, 8)

            Button(String(localized: "about.welcome.reopen")) {
                reopenWelcome()
            }
            .controlSize(.small)
        }
        .padding()
    }
}
