import AppKit
import SwiftUI
import Combine
import SceneCore

final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    @Published private(set) var permissionGranted: Bool = false
    lazy var coordinator = Coordinator(onPermissionChange: { [weak self] granted in
        DispatchQueue.main.async {
            self?.permissionGranted = granted
        }
    })

    func applicationDidFinishLaunching(_ notification: Notification) {
        coordinator.start()
    }
}
