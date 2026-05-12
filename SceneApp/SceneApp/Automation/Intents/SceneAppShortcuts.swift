import AppIntents

/// Surfaces all 5 intents in Shortcuts.app, Spotlight, and Siri.
/// Phrases prefix with `\(.applicationName)` to disambiguate from
/// macOS-system "workspace" / "layout" vocabulary.
struct SceneAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ActivateWorkspaceIntent(),
            phrases: [
                "Activate \(.applicationName) workspace \(\.$workspace)",
                "Switch to \(\.$workspace) in \(.applicationName)"
            ],
            shortTitle: "Activate Workspace",
            systemImageName: "rectangle.3.group"
        )
        AppShortcut(
            intent: ApplyLayoutIntent(),
            phrases: [
                "Apply \(.applicationName) layout \(\.$layout)"
            ],
            shortTitle: "Apply Layout",
            systemImageName: "rectangle.split.2x1"
        )
        AppShortcut(
            intent: ToggleFreeModeIntent(),
            phrases: [
                "Toggle \(.applicationName) Free Mode"
            ],
            shortTitle: "Toggle Free Mode",
            systemImageName: "pause.rectangle"
        )
        AppShortcut(
            intent: SetFreeModeIntent(),
            phrases: [
                "Set \(.applicationName) Free Mode"
            ],
            shortTitle: "Set Free Mode",
            systemImageName: "pause.rectangle"
        )
        AppShortcut(
            intent: ListWorkspacesIntent(),
            phrases: [
                "List \(.applicationName) workspaces"
            ],
            shortTitle: "List Workspaces",
            systemImageName: "list.bullet.rectangle"
        )
    }
}
