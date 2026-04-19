import Foundation

/// A token returned by store-style observation APIs (`SettingsStore.onChange`,
/// `LayoutStore.onChange`). Calling `cancel()` — or letting the token deinit —
/// removes the underlying observer. SceneCore intentionally avoids `Combine` to
/// keep the framework neutral; this is the closure-based equivalent.
public final class Cancellable {
    private let cancelHandler: () -> Void
    private var cancelled = false

    public init(_ handler: @escaping () -> Void) {
        self.cancelHandler = handler
    }

    public func cancel() {
        guard !cancelled else { return }
        cancelled = true
        cancelHandler()
    }

    deinit { cancel() }
}
