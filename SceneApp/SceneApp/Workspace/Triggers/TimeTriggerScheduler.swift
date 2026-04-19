import Foundation
import SceneCore

/// Fires `.timeOfDay` triggers at configured (weekday, hour, minute) slots.
/// Resolution: polls once per 30 seconds. Debounce: each Workspace+minute pair
/// fires at most once per minute (tracked via `lastFired`).
@MainActor
final class TimeTriggerScheduler {
    private var timer: Timer?
    private let workspaces: () -> [Workspace]
    private let onEvent: (_ workspaceID: UUID, _ trigger: WorkspaceTrigger) -> Void
    private var lastFired: [UUID: Date] = [:]
    private let calendar = Calendar.current

    init(
        workspaces: @escaping () -> [Workspace],
        onEvent: @escaping (UUID, WorkspaceTrigger) -> Void
    ) {
        self.workspaces = workspaces
        self.onEvent = onEvent
    }

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick(now: Date()) }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func tick(now: Date) {
        let components = calendar.dateComponents([.weekday, .hour, .minute], from: now)
        guard let weekday = components.weekday,
              let hour = components.hour,
              let minute = components.minute else { return }

        // Calendar.weekday: 1 = Sunday ... 7 = Saturday
        let mask: WorkspaceTrigger.WeekdayMask = {
            switch weekday {
            case 1: return .sunday
            case 2: return .monday
            case 3: return .tuesday
            case 4: return .wednesday
            case 5: return .thursday
            case 6: return .friday
            case 7: return .saturday
            default: return []
            }
        }()

        for workspace in workspaces() {
            for trigger in workspace.triggers {
                if case .timeOfDay(let wmask, let h, let m) = trigger,
                   wmask.contains(mask),
                   h == hour,
                   m == minute {
                    // Debounce: only fire once per minute per workspace
                    if let last = lastFired[workspace.id],
                       calendar.isDate(last, equalTo: now, toGranularity: .minute) {
                        continue
                    }
                    lastFired[workspace.id] = now
                    onEvent(workspace.id, trigger)
                }
            }
        }
    }
}
