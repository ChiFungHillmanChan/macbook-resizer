import Foundation

/// All automation entry points (URL scheme, AppIntents, future CLI) build one
/// of these and hand it to the SceneApp-side dispatcher. Keeping the type in
/// SceneCore lets us unit-test routing/parsing without booting AppKit.
public enum AutomationCommand: Equatable, Sendable {
    case applyLayout(id: LayoutIdentifier, force: Bool, screen: ScreenSelector)
    case activateWorkspace(id: WorkspaceIdentifier, force: Bool)
    case listWorkspaces
    case toggleFreeMode
    case setFreeMode(enabled: Bool)
}

public enum LayoutIdentifier: Equatable, Sendable {
    case uuid(UUID)
    case name(String)
}

public enum WorkspaceIdentifier: Equatable, Sendable {
    case uuid(UUID)
    case name(String)
}

public enum ScreenSelector: Equatable, Sendable {
    case underMouse
    case primary
    case index(Int)
}

/// Result of dispatching an `AutomationCommand`. Distinguishes the failure
/// modes the URL-scheme layer needs to surface (`notify`) from those the
/// AppIntents layer needs to surface (`IntentDialog` / thrown error). The
/// dispatcher returns this; URL/AppIntent translate it.
public enum AutomationOutcome: Equatable, Sendable {
    case ok
    case okWithValue([String])         // for listWorkspaces
    case notFoundWorkspace(String)
    case notFoundLayout(String)
    case blockedByFreeMode
    case blockedByMissingAX
    case invalidArgument(String)
}
