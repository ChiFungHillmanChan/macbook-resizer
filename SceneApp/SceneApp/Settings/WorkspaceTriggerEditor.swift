import AppKit
import EventKit
import SwiftUI
import SceneCore

/// Editor for `[WorkspaceTrigger]`. Renders one row per trigger and a footer
/// row with a "kind" picker + "Add" button. Each trigger kind has its own
/// sub-editor (monitor name picker / time+weekday / calendar keyword).
///
/// Calendar permission is requested lazily — the first time the user adds a
/// `.calendarEvent` trigger, we dispatch `calendarPermissionRequester` (which
/// the injector wires to `CalendarTriggerWatcher.requestAccess()`). If the
/// user denies, we still persist the trigger; the watcher's tick loop silently
/// no-ops when authorization is absent, matching the documented behavior in
/// `CalendarTriggerWatcher`.
struct WorkspaceTriggerEditor: View {
    @Binding var triggers: [WorkspaceTrigger]
    let calendarPermissionRequester: () async -> Bool
    @State private var addingKind: TriggerKind = .manual
    @State private var calendarAuthorized: Bool = false
    @State private var calendarAuthStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)

    enum TriggerKind: String, CaseIterable, Identifiable {
        case manual, monitorConnect, monitorDisconnect, timeOfDay, calendarEvent
        var id: String { rawValue }
        var label: LocalizedStringKey {
            switch self {
            case .manual:            return "trigger.kind.manual"
            case .monitorConnect:    return "trigger.kind.monitor_connect"
            case .monitorDisconnect: return "trigger.kind.monitor_disconnect"
            case .timeOfDay:         return "trigger.kind.time_of_day"
            case .calendarEvent:     return "trigger.kind.calendar_event"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if triggers.isEmpty {
                Text("trigger.none").font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(Array(triggers.enumerated()), id: \.offset) { index, trigger in
                    HStack(alignment: .center) {
                        triggerRow(trigger: trigger, index: index)
                        Spacer()
                        Button(action: { triggers.remove(at: index) }) {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("trigger.remove")
                    }
                }
            }
            HStack {
                Picker("trigger.add.kind", selection: $addingKind) {
                    ForEach(TriggerKind.allCases) { kind in
                        Text(kind.label).tag(kind)
                    }
                }
                Button("trigger.add.button") {
                    Task { await appendTrigger(kind: addingKind) }
                }
            }
            if shouldShowCalendarDeniedHint {
                Text("trigger.calendar.denied_hint")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .onAppear { refreshCalendarAuthStatus() }
    }

    /// Show the denied hint when either (a) the user is about to add a
    /// calendar trigger and permission is denied, or (b) at least one
    /// `.calendarEvent` trigger already exists and permission is denied —
    /// so reopening the editor surfaces the state.
    private var shouldShowCalendarDeniedHint: Bool {
        guard calendarAuthStatus == .denied else { return false }
        if addingKind == .calendarEvent { return true }
        return triggers.contains { if case .calendarEvent = $0 { return true } else { return false } }
    }

    private func refreshCalendarAuthStatus() {
        calendarAuthStatus = EKEventStore.authorizationStatus(for: .event)
        if #available(macOS 14.0, *) {
            calendarAuthorized = (calendarAuthStatus == .fullAccess)
        } else {
            calendarAuthorized = (calendarAuthStatus == .authorized)
        }
    }

    @ViewBuilder
    private func triggerRow(trigger: WorkspaceTrigger, index: Int) -> some View {
        switch trigger {
        case .manual:
            Text("trigger.manual.description").foregroundStyle(.secondary)
        case .monitorConnect(let name):
            MonitorNameEditor(
                name: Binding(
                    get: { name },
                    set: { triggers[index] = .monitorConnect(displayName: $0) }
                ),
                labelKey: "trigger.monitor_connect.label"
            )
        case .monitorDisconnect(let name):
            MonitorNameEditor(
                name: Binding(
                    get: { name },
                    set: { triggers[index] = .monitorDisconnect(displayName: $0) }
                ),
                labelKey: "trigger.monitor_disconnect.label"
            )
        case .timeOfDay(let mask, let hour, let minute):
            TimeTriggerRow(
                mask: Binding(
                    get: { mask },
                    set: { triggers[index] = .timeOfDay(weekdayMask: $0, hour: hour, minute: minute) }
                ),
                hour: Binding(
                    get: { hour },
                    set: { triggers[index] = .timeOfDay(weekdayMask: mask, hour: $0, minute: minute) }
                ),
                minute: Binding(
                    get: { minute },
                    set: { triggers[index] = .timeOfDay(weekdayMask: mask, hour: hour, minute: $0) }
                )
            )
        case .calendarEvent(let keyword):
            CalendarTriggerRow(
                keyword: Binding(
                    get: { keyword },
                    set: { triggers[index] = .calendarEvent(keywordContains: $0) }
                )
            )
        }
    }

    // MARK: - Add

    private func appendTrigger(kind: TriggerKind) async {
        if kind == .calendarEvent && !calendarAuthorized {
            // Only prompt the system sheet when status is .notDetermined; once
            // the user denies, Apple won't show the sheet again — we surface
            // `trigger.calendar.denied_hint` instead so the user can grant via
            // System Settings.
            if calendarAuthStatus == .notDetermined {
                calendarAuthorized = await calendarPermissionRequester()
            }
            refreshCalendarAuthStatus()
            // We append the trigger regardless — the watcher no-ops silently if
            // permission is denied, and the user can revoke later without
            // breaking the Workspace record.
        }
        triggers.append(defaultTrigger(for: kind))
    }

    private func defaultTrigger(for kind: TriggerKind) -> WorkspaceTrigger {
        switch kind {
        case .manual:
            return .manual
        case .monitorConnect:
            return .monitorConnect(displayName: NSScreen.main?.localizedName ?? "")
        case .monitorDisconnect:
            return .monitorDisconnect(displayName: NSScreen.main?.localizedName ?? "")
        case .timeOfDay:
            return .timeOfDay(weekdayMask: .weekdays, hour: 9, minute: 0)
        case .calendarEvent:
            return .calendarEvent(keywordContains: "")
        }
    }
}

// MARK: - Sub-editors

private struct MonitorNameEditor: View {
    @Binding var name: String
    let labelKey: LocalizedStringKey

    var body: some View {
        HStack {
            Text(labelKey)
            Picker("", selection: $name) {
                ForEach(NSScreen.screens, id: \.localizedName) { screen in
                    Text(screen.localizedName).tag(screen.localizedName)
                }
                // Preserve the user's stored name even if the monitor is
                // currently disconnected, so the trigger doesn't silently
                // reset to a different screen on edit.
                if !NSScreen.screens.contains(where: { $0.localizedName == name }) && !name.isEmpty {
                    Text(name).tag(name)
                }
            }
            .labelsHidden()
        }
    }
}

private struct TimeTriggerRow: View {
    @Binding var mask: WorkspaceTrigger.WeekdayMask
    @Binding var hour: Int
    @Binding var minute: Int

    var body: some View {
        HStack {
            Text("trigger.time_of_day.at")
            Stepper(
                value: Binding(
                    get: { hour * 60 + minute },
                    set: { total in
                        let clamped = max(0, min(23 * 60 + 59, total))
                        hour = clamped / 60
                        minute = clamped % 60
                    }
                ),
                in: 0...(23 * 60 + 59),
                step: 5
            ) {
                Text("\(hour):\(String(format: "%02d", minute))")
            }
            .labelsHidden()
            Text("trigger.time_of_day.days")
            WeekdayMaskEditor(mask: $mask)
        }
    }
}

private struct WeekdayMaskEditor: View {
    @Binding var mask: WorkspaceTrigger.WeekdayMask

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(weekdayPairs.enumerated()), id: \.offset) { _, pair in
                Button(action: {
                    if mask.contains(pair.day) { mask.remove(pair.day) }
                    else { mask.insert(pair.day) }
                }) {
                    Text(pair.label)
                        .font(.caption2)
                        .frame(width: 22)
                        .padding(.vertical, 2)
                        .background(mask.contains(pair.day) ? Color.accentColor : Color.secondary.opacity(0.2))
                        .foregroundColor(mask.contains(pair.day) ? .white : .primary)
                        .cornerRadius(3)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var weekdayPairs: [(day: WorkspaceTrigger.WeekdayMask, label: LocalizedStringKey)] {
        [
            (.monday,    "weekday.mon.short"),
            (.tuesday,   "weekday.tue.short"),
            (.wednesday, "weekday.wed.short"),
            (.thursday,  "weekday.thu.short"),
            (.friday,    "weekday.fri.short"),
            (.saturday,  "weekday.sat.short"),
            (.sunday,    "weekday.sun.short"),
        ]
    }
}

private struct CalendarTriggerRow: View {
    @Binding var keyword: String

    var body: some View {
        HStack {
            Text("trigger.calendar.contains")
            TextField("trigger.calendar.keyword", text: $keyword)
        }
    }
}
