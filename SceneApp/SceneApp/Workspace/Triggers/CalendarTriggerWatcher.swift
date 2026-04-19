import EventKit
import Foundation
import SceneCore

/// Observes the user's Calendar for events whose title contains a configured
/// keyword, and fires `.calendarEvent(keywordContains:)` triggers when a matching
/// event starts within a 5-minute lookahead window.
///
/// Permission is **lazy**: `requestAccess()` is a public async method, called
/// by the editor UI (Block D Task 27) when the user first adds a
/// `.calendarEvent` trigger. `start()` and `tick()` silently no-op if permission
/// is not granted — we do not prompt at app launch.
///
/// Polling: once per 60 seconds. Debounce: each (workspace, event) pair fires
/// at most once; entries older than 1 hour are garbage-collected each tick.
@MainActor
final class CalendarTriggerWatcher {
    private let eventStore = EKEventStore()
    private var timer: Timer?
    private let workspaces: () -> [Workspace]
    private let onEvent: (_ workspaceID: UUID, _ trigger: WorkspaceTrigger) -> Void
    private var lastFiredForEvent: [String: Date] = [:]  // key: "<workspaceID>-<eventIdentifier>"

    /// Poll window: 60 seconds. Match window: events starting in next 5 minutes.
    private let pollInterval: TimeInterval = 60.0
    private let matchWindow: TimeInterval = 5 * 60.0

    init(
        workspaces: @escaping () -> [Workspace],
        onEvent: @escaping (UUID, WorkspaceTrigger) -> Void
    ) {
        self.workspaces = workspaces
        self.onEvent = onEvent
    }

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.tick() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Request Calendar permission. Called from the editor when user adds their
    /// first `.calendarEvent` trigger. Never called automatically.
    func requestAccess() async -> Bool {
        do {
            if #available(macOS 14.0, *) {
                return try await eventStore.requestFullAccessToEvents()
            } else {
                return try await eventStore.requestAccess(to: .event)
            }
        } catch {
            NSLog("[Scene] CalendarTriggerWatcher.requestAccess failed: \(error)")
            return false
        }
    }

    func authorizationStatus() -> EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    private func tick() async {
        let status = authorizationStatus()
        if #available(macOS 14.0, *) {
            guard status == .fullAccess else { return }
        } else {
            guard status == .authorized else { return }
        }

        let workspacesWithCalendarTriggers = workspaces().filter { w in
            w.triggers.contains { if case .calendarEvent = $0 { return true } else { return false } }
        }
        if workspacesWithCalendarTriggers.isEmpty { return }

        let now = Date()
        let future = now.addingTimeInterval(matchWindow)
        let predicate = eventStore.predicateForEvents(withStart: now, end: future, calendars: nil)
        let events = eventStore.events(matching: predicate)

        for workspace in workspacesWithCalendarTriggers {
            for trigger in workspace.triggers {
                guard case .calendarEvent(let keyword) = trigger else { continue }
                for event in events {
                    let title = event.title ?? ""
                    if title.range(of: keyword, options: .caseInsensitive) != nil {
                        let key = "\(workspace.id.uuidString)-\(event.eventIdentifier ?? "")"
                        if lastFiredForEvent[key] != nil { continue }
                        lastFiredForEvent[key] = now
                        onEvent(workspace.id, trigger)
                    }
                }
            }
        }

        // Garbage-collect entries older than 1 hour to bound memory
        let cutoff = now.addingTimeInterval(-3600)
        lastFiredForEvent = lastFiredForEvent.filter { $0.value > cutoff }
    }
}
