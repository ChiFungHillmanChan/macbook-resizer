import Foundation

/// How a Workspace can be activated. A Workspace has 0+ triggers; the first
/// matching trigger in the ordered list wins. See `TriggerSupervisor`.
public enum WorkspaceTrigger: Codable, Equatable, Hashable, Sendable {
    case manual
    case monitorConnect(displayName: String)
    case monitorDisconnect(displayName: String)
    case timeOfDay(weekdayMask: WeekdayMask, hour: Int, minute: Int)
    case calendarEvent(keywordContains: String)

    public struct WeekdayMask: OptionSet, Codable, Hashable, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let monday    = WeekdayMask(rawValue: 1 << 0)
        public static let tuesday   = WeekdayMask(rawValue: 1 << 1)
        public static let wednesday = WeekdayMask(rawValue: 1 << 2)
        public static let thursday  = WeekdayMask(rawValue: 1 << 3)
        public static let friday    = WeekdayMask(rawValue: 1 << 4)
        public static let saturday  = WeekdayMask(rawValue: 1 << 5)
        public static let sunday    = WeekdayMask(rawValue: 1 << 6)

        public static let weekdays: WeekdayMask = [.monday, .tuesday, .wednesday, .thursday, .friday]
        public static let weekends: WeekdayMask = [.saturday, .sunday]
        public static let all: WeekdayMask = [.weekdays, .weekends]
    }

    // MARK: - Codable (explicit discriminator)

    private enum CodingKeys: String, CodingKey {
        case type, displayName, weekdayMask, hour, minute, keywordContains
    }

    private enum TypeName: String, Codable {
        case manual, monitorConnect, monitorDisconnect, timeOfDay, calendarEvent
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(TypeName.self, forKey: .type)
        switch type {
        case .manual:
            self = .manual
        case .monitorConnect:
            self = .monitorConnect(displayName: try c.decode(String.self, forKey: .displayName))
        case .monitorDisconnect:
            self = .monitorDisconnect(displayName: try c.decode(String.self, forKey: .displayName))
        case .timeOfDay:
            self = .timeOfDay(
                weekdayMask: try c.decode(WeekdayMask.self, forKey: .weekdayMask),
                hour: try c.decode(Int.self, forKey: .hour),
                minute: try c.decode(Int.self, forKey: .minute)
            )
        case .calendarEvent:
            self = .calendarEvent(keywordContains: try c.decode(String.self, forKey: .keywordContains))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .manual:
            try c.encode(TypeName.manual, forKey: .type)
        case .monitorConnect(let name):
            try c.encode(TypeName.monitorConnect, forKey: .type)
            try c.encode(name, forKey: .displayName)
        case .monitorDisconnect(let name):
            try c.encode(TypeName.monitorDisconnect, forKey: .type)
            try c.encode(name, forKey: .displayName)
        case .timeOfDay(let mask, let h, let m):
            try c.encode(TypeName.timeOfDay, forKey: .type)
            try c.encode(mask, forKey: .weekdayMask)
            try c.encode(h, forKey: .hour)
            try c.encode(m, forKey: .minute)
        case .calendarEvent(let kw):
            try c.encode(TypeName.calendarEvent, forKey: .type)
            try c.encode(kw, forKey: .keywordContains)
        }
    }
}
