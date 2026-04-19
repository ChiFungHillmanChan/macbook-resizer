import Foundation
import Combine
import SceneCore

@MainActor
final class Coordinator: ObservableObject {
    private let onPermissionChange: (Bool) -> Void
    init(onPermissionChange: @escaping (Bool) -> Void) {
        self.onPermissionChange = onPermissionChange
    }
    func start() { onPermissionChange(AXPermission.check()) }
    func applyLayout(_ id: LayoutID) {}
}
