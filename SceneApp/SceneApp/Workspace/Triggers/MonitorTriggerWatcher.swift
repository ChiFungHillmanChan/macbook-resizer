import AppKit
import Combine
import SceneCore

/// Observes external monitor connect/disconnect events by diffing the
/// `NSScreen.screens` snapshot on `NSApplication.didChangeScreenParametersNotification`.
/// Fires `.monitorConnect(displayName:)` / `.monitorDisconnect(displayName:)`
/// into the provided `onEvent` callback, which the `TriggerSupervisor` routes.
@MainActor
final class MonitorTriggerWatcher {
    private var lastScreenNames: Set<String> = []
    private var observer: NSObjectProtocol?
    private let onEvent: (WorkspaceTrigger) -> Void

    init(onEvent: @escaping (WorkspaceTrigger) -> Void) {
        self.onEvent = onEvent
    }

    func start() {
        guard observer == nil else { return }
        lastScreenNames = Set(NSScreen.screens.map { $0.localizedName })
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in self.handleScreenChange() }
        }
    }

    func stop() {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
        lastScreenNames.removeAll()
    }

    private func handleScreenChange() {
        let current = Set(NSScreen.screens.map { $0.localizedName })
        let connected = current.subtracting(lastScreenNames)
        let disconnected = lastScreenNames.subtracting(current)
        for name in connected {
            onEvent(.monitorConnect(displayName: name))
        }
        for name in disconnected {
            onEvent(.monitorDisconnect(displayName: name))
        }
        lastScreenNames = current
    }
}
