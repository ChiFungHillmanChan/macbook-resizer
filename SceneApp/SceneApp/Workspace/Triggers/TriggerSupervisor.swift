import Foundation
import SceneCore

/// Aggregates the 3 trigger watchers (monitor, time, calendar) and implements:
///   - 30s cooldown per workspace (auto-triggers only; manual bypasses).
///   - First-match-wins for system events: iterates workspaces in order, the
///     first whose `triggers.contains(systemEvent)` fires, then `return`.
///   - De-thrash: already-active workspaces are not re-activated by auto-triggers.
///
/// `TriggerSupervisor` is constructed by `AppDelegate` (Block D) once both
/// `WorkspaceStore` and `WorkspaceActivator` exist. It holds neither strongly
/// owns the supervisor — `Coordinator` does, via `triggerSupervisor: TriggerSupervisor?`.
@MainActor
final class TriggerSupervisor {
    private let workspaceStore: WorkspaceStore
    private let activator: WorkspaceActivator
    private var monitorWatcher: MonitorTriggerWatcher!
    private var timeScheduler: TimeTriggerScheduler!
    private var calendarWatcher: CalendarTriggerWatcher!
    private var lastActivation: [UUID: Date] = [:]
    private let cooldown: TimeInterval = 30.0

    init(workspaceStore: WorkspaceStore, activator: WorkspaceActivator) {
        self.workspaceStore = workspaceStore
        self.activator = activator
        self.monitorWatcher = MonitorTriggerWatcher { [weak self] trigger in
            self?.handle(systemEvent: trigger)
        }
        self.timeScheduler = TimeTriggerScheduler(
            workspaces: { [weak workspaceStore] in workspaceStore?.workspaces ?? [] },
            onEvent: { [weak self] id, _ in
                self?.handleDirectActivation(workspaceID: id)
            }
        )
        self.calendarWatcher = CalendarTriggerWatcher(
            workspaces: { [weak workspaceStore] in workspaceStore?.workspaces ?? [] },
            onEvent: { [weak self] id, _ in
                self?.handleDirectActivation(workspaceID: id)
            }
        )
    }

    func start() {
        monitorWatcher.start()
        timeScheduler.start()
        calendarWatcher.start()
    }

    func stop() {
        monitorWatcher.stop()
        timeScheduler.stop()
        calendarWatcher.stop()
    }

    /// Exposed so the editor UI (Block D Task 27) can prompt for Calendar
    /// permission lazily when the user adds their first `.calendarEvent` trigger.
    var calendar: CalendarTriggerWatcher { calendarWatcher }

    /// Manual activation (hotkey or menu click). Bypasses cooldown per §4.13.
    func activateManually(workspaceID: UUID) {
        lastActivation[workspaceID] = Date()
        Task { @MainActor in await activator.activate(workspaceID: workspaceID) }
    }

    /// System-event triggers (monitor/time/calendar). First match wins.
    private func handle(systemEvent: WorkspaceTrigger) {
        for workspace in workspaceStore.workspaces {
            guard workspace.triggers.contains(systemEvent) else { continue }
            handleDirectActivation(workspaceID: workspace.id)
            return  // first match wins
        }
    }

    private func handleDirectActivation(workspaceID: UUID) {
        // Skip if already active (avoid thrash).
        if workspaceStore.activeWorkspaceID == workspaceID { return }
        // Cooldown (auto-triggers only; manual path bypasses).
        if let last = lastActivation[workspaceID], Date().timeIntervalSince(last) < cooldown {
            return
        }
        lastActivation[workspaceID] = Date()
        Task { @MainActor in await activator.activate(workspaceID: workspaceID) }
    }
}
