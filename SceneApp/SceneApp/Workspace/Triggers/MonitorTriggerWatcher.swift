import AppKit
import Combine
import SceneCore

/// Observes external monitor connect/disconnect events by diffing the
/// `NSScreen.screens` snapshot on `NSApplication.didChangeScreenParametersNotification`.
/// Fires `.monitorConnect(displayName:)` / `.monitorDisconnect(displayName:)`
/// into the provided `onEvent` callback, which the `TriggerSupervisor` routes.
///
/// V0.6: every screen-parameter change (resolution, vf, scale, main-flag,
/// id set) is reported as a `screenDiff` diagnostic event regardless of
/// whether a connect/disconnect was inferred. This gives the export
/// bundle a complete history of arrangement state changes — enough to
/// answer "what did the user's display setup look like 30 seconds before
/// the freeze" without needing video.
@MainActor
final class MonitorTriggerWatcher {
    private var lastScreenNames: Set<String> = []
    private var lastScreenRecords: [ScreenRecord] = []
    private var observer: NSObjectProtocol?
    private let onEvent: (WorkspaceTrigger) -> Void
    private let diagnostics: DiagnosticSink

    init(
        onEvent: @escaping (WorkspaceTrigger) -> Void,
        diagnostics: DiagnosticSink = .noop
    ) {
        self.onEvent = onEvent
        self.diagnostics = diagnostics
    }

    func start() {
        guard observer == nil else { return }
        lastScreenNames = Set(NSScreen.screens.map { $0.localizedName })
        lastScreenRecords = EnvironmentCapture.currentScreenRecords()
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
        lastScreenRecords.removeAll()
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

        // Always log the diff — even when names didn't change but the
        // arrangement did (resolution/scale/main-flag/etc.).
        let nextRecords = EnvironmentCapture.currentScreenRecords()
        let beforeSig = EnvironmentSnapshot.signature(of: lastScreenRecords.sorted { $0.id < $1.id }, activeID: 0)
        let afterSig = EnvironmentSnapshot.signature(of: nextRecords.sorted { $0.id < $1.id }, activeID: 0)
        if beforeSig != afterSig {
            diagnostics.log(.screenDiff(.init(
                beforeSig: beforeSig,
                afterSig: afterSig,
                beforeScreens: lastScreenRecords,
                afterScreens: nextRecords
            )))
        }
        lastScreenRecords = nextRecords
    }
}
