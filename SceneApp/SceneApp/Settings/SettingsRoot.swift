import SwiftUI

/// Root view of the Settings window. Sidebar nav with 4 tabs.
struct SettingsRoot: View {
    enum Tab: String, CaseIterable, Identifiable {
        case layouts, hotkeys, animation, about

        var id: String { rawValue }

        var label: String {
            switch self {
            case .layouts:   return "Layouts"
            case .hotkeys:   return "Hotkeys"
            case .animation: return "Animation"
            case .about:     return "About"
            }
        }

        var symbol: String {
            switch self {
            case .layouts:   return "rectangle.split.2x2"
            case .hotkeys:   return "command"
            case .animation: return "play.rectangle"
            case .about:     return "info.circle"
            }
        }
    }

    @State private var selection: Tab = .layouts

    var body: some View {
        NavigationSplitView {
            List(Tab.allCases, selection: $selection) { tab in
                Label(tab.label, systemImage: tab.symbol).tag(tab)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
        } detail: {
            Group {
                switch selection {
                case .layouts:   LayoutsTab()
                case .hotkeys:   HotkeysTab()
                case .animation: AnimationTab()
                case .about:     AboutTab()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }
    }
}
