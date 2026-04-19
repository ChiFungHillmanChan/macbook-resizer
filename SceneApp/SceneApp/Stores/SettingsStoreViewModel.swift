import Combine
import Foundation
import SceneCore
import class SceneCore.Cancellable

/// SwiftUI-friendly adapter around `SettingsStore`. Republishes the current
/// `AnimationConfig` so SwiftUI can bind to it. See `LayoutStoreViewModel`
/// for an explanation of the `import class SceneCore.Cancellable` shadowing.
@MainActor
final class SettingsStoreViewModel: ObservableObject {
    let store: SettingsStore
    @Published private(set) var animation: AnimationConfig
    @Published private(set) var dragSwap: DragSwapConfig
    private var token: Cancellable?

    init(store: SettingsStore) {
        self.store = store
        self.animation = store.animation
        self.dragSwap = store.dragSwap
        let weakSelf = WeakBox(self)
        self.token = store.onChange {
            Task { @MainActor in
                guard let strong = weakSelf.value else { return }
                strong.animation = strong.store.animation
                strong.dragSwap = strong.store.dragSwap
            }
        }
    }
}

private final class WeakBox<T: AnyObject> {
    weak var value: T?
    init(_ value: T) { self.value = value }
}
