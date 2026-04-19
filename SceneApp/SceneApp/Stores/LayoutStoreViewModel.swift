import Combine
import Foundation
import SceneCore
import class SceneCore.Cancellable

/// SwiftUI-friendly adapter around `LayoutStore`.
///
/// `LayoutStore` is a plain class with closure-based observation. This wrapper
/// republishes its `layouts` array through `@Published` so SwiftUI views can
/// bind to it directly via `@EnvironmentObject` / `@ObservedObject`.
///
/// The `import class SceneCore.Cancellable` form pulls the concrete class into
/// the file's top-level namespace and shadows `Combine.Cancellable`, which is
/// otherwise brought in by `import Combine` (required for `ObservableObject`).
@MainActor
final class LayoutStoreViewModel: ObservableObject {
    let store: LayoutStore
    @Published private(set) var layouts: [CustomLayout] = []
    private var token: Cancellable?

    init(store: LayoutStore) {
        self.store = store
        self.layouts = store.layouts
        // Subscribe to store changes; the closure runs on whatever thread the
        // store mutates on. The Coordinator already mutates LayoutStore on the
        // main thread, but be defensive and hop through `Task { @MainActor }`.
        let weakSelf = WeakBox(self)
        self.token = store.onChange {
            Task { @MainActor in
                guard let strong = weakSelf.value else { return }
                strong.layouts = strong.store.layouts
            }
        }
    }
}

private final class WeakBox<T: AnyObject> {
    weak var value: T?
    init(_ value: T) { self.value = value }
}
