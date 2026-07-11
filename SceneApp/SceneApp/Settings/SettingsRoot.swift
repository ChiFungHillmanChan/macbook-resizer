import SwiftUI

/// Root view of the Settings window. Sidebar nav with 5 tabs in the V0.4 order
/// locked by spec §4.15: Workspaces (first-class marquee) → Layouts → Hotkeys
/// → Interaction → About.
struct SettingsRoot: View {
    enum Tab: String, CaseIterable, Identifiable {
        case workspaces, layouts, hotkeys, interaction, about

        var id: String { rawValue }

        var label: LocalizedStringKey {
            switch self {
            case .workspaces:  return "settings.tab.workspaces"
            case .layouts:     return "settings.tab.layouts"
            case .hotkeys:     return "settings.tab.hotkeys"
            case .interaction: return "settings.tab.interaction"
            case .about:       return "settings.tab.about"
            }
        }

        var symbol: String {
            switch self {
            case .workspaces:  return "square.stack.3d.up"
            case .layouts:     return "rectangle.split.2x2"
            case .hotkeys:     return "command"
            case .interaction: return "hand.draw"
            case .about:       return "info.circle"
            }
        }
    }

    @EnvironmentObject var layoutVM: LayoutStoreViewModel
    @EnvironmentObject var workspaceVM: WorkspaceStoreViewModel
    let calendarPermissionRequester: () async -> Bool
    let reopenWelcome: () -> Void
    let exportDiagnostics: () async -> Void

    @State private var selection: Tab = .workspaces

    var body: some View {
        NavigationSplitView {
            List(Tab.allCases, selection: $selection) { tab in
                Label(tab.label, systemImage: tab.symbol).tag(tab)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
        } detail: {
            Group {
                switch selection {
                case .workspaces:
                    WorkspacesTab(
                        workspaceStore: workspaceVM,
                        layoutStore: layoutVM,
                        calendarPermissionRequester: calendarPermissionRequester
                    )
                case .layouts:     LayoutsTab()
                case .hotkeys:     HotkeysTab()
                case .interaction: InteractionTab()
                case .about:       AboutTab(reopenWelcome: reopenWelcome, exportDiagnostics: exportDiagnostics)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding()
            .modifier(DetailTabChrome())
        }
    }
}

/// Identical top chrome for every detail tab. Workspaces/Layouts declare
/// their own toolbar items and would otherwise be the only tabs with a
/// title strip; List/Form tabs would also paint opaque scroll backgrounds
/// over the window material. No-op on macOS 14/15.
private struct DetailTabChrome: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .navigationTitle("settings.window.title")
                .scrollContentBackground(.hidden)
        } else {
            content
        }
    }
}
