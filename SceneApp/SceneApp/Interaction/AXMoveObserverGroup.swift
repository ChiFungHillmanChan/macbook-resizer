import AppKit
import ApplicationServices
import CoreGraphics
import os
import SceneCore

/// Conforms to `SceneCore.WindowMoveObserving`. Wraps one `AXObserver` per
/// placed window (V0.3 only subscribes to `kAXMovedNotification`). Rebuilds
/// wholesale on every `startObserving(windowIDs:onMove:)` call — the Coordinator
/// calls this after every `applyLayout`.
///
/// Lifecycle: the group holds the `AXObserver` + `AXUIElement` references
/// (retaining them prevents deallocation while they're on the run loop).
/// `stopObserving()` removes them from the main run loop and releases the refs.
@MainActor
final class AXMoveObserverGroup: WindowMoveObserving {
    private struct Entry {
        let observer: AXObserver
        let element: AXUIElement
    }

    private var entries: [CGWindowID: Entry] = [:]
    private var onMove: ((CGWindowID, CGRect) -> Void)?
    private let log = Logger(subsystem: "com.scene.app", category: "ax-observer")

    func startObserving(
        windowIDs: Set<CGWindowID>,
        onMove: @escaping (CGWindowID, CGRect) -> Void
    ) {
        stopObserving()
        self.onMove = onMove

        for id in windowIDs {
            guard let element = AXWindowLookup.element(for: id) else {
                log.debug("skip observer for id=\(id, privacy: .public) — AX lookup failed")
                continue
            }
            var pid: pid_t = 0
            AXUIElementGetPid(element, &pid)

            var observer: AXObserver?
            let createErr = AXObserverCreate(pid, Self.observerCallback, &observer)
            guard createErr == .success, let observer else {
                log.error("AXObserverCreate failed pid=\(pid, privacy: .public) err=\(createErr.rawValue, privacy: .public)")
                continue
            }

            let refcon = Unmanaged.passUnretained(self).toOpaque()
            let addErr = AXObserverAddNotification(
                observer,
                element,
                kAXMovedNotification as CFString,
                refcon
            )
            guard addErr == .success else {
                log.error("AXObserverAddNotification failed id=\(id, privacy: .public) err=\(addErr.rawValue, privacy: .public)")
                continue
            }

            CFRunLoopAddSource(
                CFRunLoopGetMain(),
                AXObserverGetRunLoopSource(observer),
                .commonModes
            )
            entries[id] = Entry(observer: observer, element: element)
        }
        log.info("observing \(self.entries.count, privacy: .public)/\(windowIDs.count, privacy: .public) windows")
    }

    func stopObserving() {
        for (_, entry) in entries {
            CFRunLoopRemoveSource(
                CFRunLoopGetMain(),
                AXObserverGetRunLoopSource(entry.observer),
                .commonModes
            )
            AXObserverRemoveNotification(entry.observer, entry.element, kAXMovedNotification as CFString)
        }
        entries.removeAll()
        onMove = nil
    }

    // C-style callback: no captured context allowed. Pull self back from refcon.
    // The AXObserver fires on the main run loop (because we added its source to
    // CFRunLoopGetMain()), so we're already on main here. Still use
    // MainActor.assumeIsolated to satisfy strict concurrency.
    private static let observerCallback: AXObserverCallback = { _, element, _, refcon in
        guard let refcon else { return }
        let group = Unmanaged<AXMoveObserverGroup>.fromOpaque(refcon).takeUnretainedValue()
        MainActor.assumeIsolated {
            // Resolve element → CGWindowID via reverse lookup
            var foundID: CGWindowID?
            for (wid, entry) in group.entries where CFEqual(entry.element, element) {
                foundID = wid
                break
            }
            guard let id = foundID else { return }
            guard let frame = AXWindowLookup.axFrame(of: element) else { return }
            group.onMove?(id, frame)
        }
    }

    deinit {
        // deinit runs on main (class is @MainActor). Release CFRunLoopSources directly.
        for (_, entry) in entries {
            CFRunLoopRemoveSource(
                CFRunLoopGetMain(),
                AXObserverGetRunLoopSource(entry.observer),
                .commonModes
            )
        }
    }
}
