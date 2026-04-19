import CoreGraphics
import Foundation

/// User-tunable settings for the V0.3 drag-to-swap feature.
/// Persisted alongside `AnimationConfig` in `SettingsStore`.
public struct DragSwapConfig: Codable, Equatable, Sendable {
    public let enabled: Bool
    public let distanceThresholdPt: CGFloat

    public static let minThresholdPt: CGFloat = 10
    public static let maxThresholdPt: CGFloat = 100

    public init(enabled: Bool, distanceThresholdPt: CGFloat) {
        self.enabled = enabled
        self.distanceThresholdPt = min(max(distanceThresholdPt, Self.minThresholdPt), Self.maxThresholdPt)
    }

    public static let `default` = DragSwapConfig(enabled: true, distanceThresholdPt: 30)

    private enum CodingKeys: String, CodingKey { case enabled, distanceThresholdPt }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let raw = try c.decode(CGFloat.self, forKey: .distanceThresholdPt)
        self.init(
            enabled: try c.decode(Bool.self, forKey: .enabled),
            distanceThresholdPt: raw
        )
    }
}
