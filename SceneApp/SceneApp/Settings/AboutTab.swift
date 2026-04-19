import SwiftUI

/// "About Scene" tab — version + project link. Not deferred; this is real M8 content.
struct AboutTab: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("about.app_name")
                .font(.largeTitle)
                .bold()
            Text("about.version")
                .foregroundStyle(.secondary)
            Link(
                "github.com/ChiFungHillmanChan/scene",
                destination: URL(string: "https://github.com/ChiFungHillmanChan/scene")!
            )
        }
        .padding()
    }
}
