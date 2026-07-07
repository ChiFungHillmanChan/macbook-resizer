import Foundation

/// Maps a display (by its user-visible name) to a specific layout.
/// Used in `Workspace.displayLayouts` to assign different layouts to different
/// connected screens when activating a Workspace.
public struct DisplayLayoutAssignment: Codable, Equatable, Hashable, Sendable {
    /// `NSScreen.localizedName` — consistent with `WorkspaceTrigger.monitorConnect`.
    public var displayName: String
    /// Foreign key referencing `CustomLayout.id` in `LayoutStore`.
    public var layoutID: UUID

    public init(displayName: String, layoutID: UUID) {
        self.displayName = displayName
        self.layoutID = layoutID
    }
}
