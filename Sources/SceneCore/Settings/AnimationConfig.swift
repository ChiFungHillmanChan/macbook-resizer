import Foundation

public struct AnimationConfig: Codable, Equatable, Sendable {
    public let enabled: Bool
    public let durationMs: Int
    public let easing: EasingCurve

    public static let minDurationMs = 100
    public static let maxDurationMs = 500

    public init(enabled: Bool, durationMs: Int, easing: EasingCurve) {
        self.enabled = enabled
        self.durationMs = min(max(durationMs, Self.minDurationMs), Self.maxDurationMs)
        self.easing = easing
    }

    public static let `default` = AnimationConfig(enabled: true, durationMs: 250, easing: .easeOut)
}

public enum EasingCurve: String, Codable, Sendable, CaseIterable, Equatable {
    case linear, easeOut, spring
}
