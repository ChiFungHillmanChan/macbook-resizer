import Foundation

/// Mirrors `WorkspaceTrigger` but every user-authored string is replaced
/// with a `DiagnosticHasher` token. `WeekdayMask` is encoded as raw Int
/// (no PII) and hour/minute pass through unchanged.
public enum SanitizedTrigger: Codable, Sendable, Equatable {
    case manual
    case monitorConnect(displayNameHash: String)
    case monitorDisconnect(displayNameHash: String)
    case timeOfDay(weekdayMaskRaw: Int, hour: Int, minute: Int)
    case calendarEvent(keywordHash: String)

    private enum CodingKeys: String, CodingKey {
        case type, displayNameHash, weekdayMaskRaw, hour, minute, keywordHash
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
            self = .monitorConnect(displayNameHash:
                try c.decode(String.self, forKey: .displayNameHash))
        case .monitorDisconnect:
            self = .monitorDisconnect(displayNameHash:
                try c.decode(String.self, forKey: .displayNameHash))
        case .timeOfDay:
            self = .timeOfDay(
                weekdayMaskRaw: try c.decode(Int.self, forKey: .weekdayMaskRaw),
                hour: try c.decode(Int.self, forKey: .hour),
                minute: try c.decode(Int.self, forKey: .minute)
            )
        case .calendarEvent:
            self = .calendarEvent(keywordHash:
                try c.decode(String.self, forKey: .keywordHash))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .manual:
            try c.encode(TypeName.manual, forKey: .type)
        case .monitorConnect(let h):
            try c.encode(TypeName.monitorConnect, forKey: .type)
            try c.encode(h, forKey: .displayNameHash)
        case .monitorDisconnect(let h):
            try c.encode(TypeName.monitorDisconnect, forKey: .type)
            try c.encode(h, forKey: .displayNameHash)
        case .timeOfDay(let mask, let hr, let mn):
            try c.encode(TypeName.timeOfDay, forKey: .type)
            try c.encode(mask, forKey: .weekdayMaskRaw)
            try c.encode(hr, forKey: .hour)
            try c.encode(mn, forKey: .minute)
        case .calendarEvent(let h):
            try c.encode(TypeName.calendarEvent, forKey: .type)
            try c.encode(h, forKey: .keywordHash)
        }
    }
}
