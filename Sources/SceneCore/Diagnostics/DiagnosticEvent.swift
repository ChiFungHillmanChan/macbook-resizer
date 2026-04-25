import Foundation

/// Discriminated union of every event Scene's orchestration logs.
///
/// **Privacy contract.** No payload field carries user-authored text.
/// String-typed fields exist only when their name ends in `Hash` and
/// hold a `DiagnosticHasher` token (11 chars base64url). Everything else
/// is UUIDs, counts, durations, enum discriminators, or `ScreenRecord`s.
/// `EnvironmentSnapshotTests` and `DiagnosticEventTests` enforce this
/// invariant via reflection.
public enum DiagnosticEvent: Codable, Sendable, Equatable {
    case layoutFired(LayoutFiredPayload)
    case layoutOutcomeInstant(LayoutOutcomePayload)
    case layoutOutcomeAnimated(AnimatedOutcomePayload)
    case workspaceStep(WorkspaceStepPayload)
    case triggerFired(TriggerFiredPayload)
    case triggerSuppressed(TriggerSuppressedPayload)
    case screenDiff(ScreenDiffPayload)
    case axPermissionChanged(AXPermissionPayload)
    case appLaunchTimeout(AppLaunchPayload)
    case appQuitSurvivors(AppQuitPayload)

    /// Short discriminator written to disk under the `t` key. Stable —
    /// renaming a case must NOT change this string (older .jsonl.gz
    /// files still parse).
    public var typeKey: String {
        switch self {
        case .layoutFired:           return "lf"
        case .layoutOutcomeInstant:  return "loi"
        case .layoutOutcomeAnimated: return "loa"
        case .workspaceStep:         return "wst"
        case .triggerFired:          return "trf"
        case .triggerSuppressed:     return "trs"
        case .screenDiff:            return "scd"
        case .axPermissionChanged:   return "axp"
        case .appLaunchTimeout:      return "alt"
        case .appQuitSurvivors:      return "aqs"
        }
    }
}

// MARK: - Payloads

/// Target encoded sizes (per CLAUDE.md plan):
///   layoutFired           target 200 B / hard 500 B  (snapshot dominates)
///   layoutOutcome*        target 150 B / hard 300 B
///   workspaceStep         target 200 B / hard 400 B
///   triggerFired/Suppr.   target 200 B / hard 400 B
///   screenDiff            target 400 B / hard 800 B
///   others                target 100 B / hard 200 B

public struct LayoutFiredPayload: Codable, Sendable, Equatable {
    public enum Source: String, Codable, Sendable {
        case hotkey, menu, workspace
    }
    public let layoutID: UUID
    public let source: Source
    public let snapshot: EnvironmentSnapshot

    public init(layoutID: UUID, source: Source, snapshot: EnvironmentSnapshot) {
        self.layoutID = layoutID
        self.source = source
        self.snapshot = snapshot
    }
}

public struct LayoutOutcomePayload: Codable, Sendable, Equatable {
    public let layoutID: UUID
    public let placed: Int
    public let minimized: Int
    public let leftEmpty: Int
    public let failed: Int

    public init(layoutID: UUID, placed: Int, minimized: Int, leftEmpty: Int, failed: Int) {
        self.layoutID = layoutID
        self.placed = placed
        self.minimized = minimized
        self.leftEmpty = leftEmpty
        self.failed = failed
    }
}

public struct AnimatedOutcomePayload: Codable, Sendable, Equatable {
    public enum EndReason: String, Codable, Sendable {
        case normal, cancelled, interrupted
    }
    public let layoutID: UUID
    public let windowCount: Int
    public let durationMs: Int
    public let setFrameFailures: Int
    public let endReason: EndReason

    public init(
        layoutID: UUID,
        windowCount: Int,
        durationMs: Int,
        setFrameFailures: Int,
        endReason: EndReason
    ) {
        self.layoutID = layoutID
        self.windowCount = windowCount
        self.durationMs = durationMs
        self.setFrameFailures = setFrameFailures
        self.endReason = endReason
    }

    public var completedNormally: Bool { endReason == .normal }
}

public struct WorkspaceStepPayload: Codable, Sendable, Equatable {
    public enum Step: String, Codable, Sendable {
        case quit, launch, settle, applyLayout, focusOn, setActive, banner
    }
    public enum Status: String, Codable, Sendable {
        case ok, timeout, failure, skipped
    }
    public let workspaceID: UUID
    public let step: Step
    public let status: Status
    public let durationMs: Int
    public let appCount: Int
    public let survivorCount: Int

    public init(
        workspaceID: UUID,
        step: Step,
        status: Status,
        durationMs: Int,
        appCount: Int = 0,
        survivorCount: Int = 0
    ) {
        self.workspaceID = workspaceID
        self.step = step
        self.status = status
        self.durationMs = durationMs
        self.appCount = appCount
        self.survivorCount = survivorCount
    }
}

public struct TriggerFiredPayload: Codable, Sendable, Equatable {
    public enum Kind: String, Codable, Sendable {
        case manual, monitorConnect, monitorDisconnect, timeOfDay, calendarEvent
    }
    public let workspaceID: UUID
    public let kind: Kind
    public let displayNameHash: String?
    public let keywordHash: String?

    public init(
        workspaceID: UUID,
        kind: Kind,
        displayNameHash: String? = nil,
        keywordHash: String? = nil
    ) {
        self.workspaceID = workspaceID
        self.kind = kind
        self.displayNameHash = displayNameHash
        self.keywordHash = keywordHash
    }
}

public struct TriggerSuppressedPayload: Codable, Sendable, Equatable {
    public enum Reason: String, Codable, Sendable {
        case cooldown, alreadyActive, inFlight
    }
    public let workspaceID: UUID
    public let reason: Reason
    public let cooldownRemainingMs: Int?

    public init(workspaceID: UUID, reason: Reason, cooldownRemainingMs: Int? = nil) {
        self.workspaceID = workspaceID
        self.reason = reason
        self.cooldownRemainingMs = cooldownRemainingMs
    }
}

public struct ScreenDiffPayload: Codable, Sendable, Equatable {
    public let beforeSig: String
    public let afterSig: String
    public let beforeScreens: [ScreenRecord]
    public let afterScreens: [ScreenRecord]

    public init(
        beforeSig: String,
        afterSig: String,
        beforeScreens: [ScreenRecord],
        afterScreens: [ScreenRecord]
    ) {
        self.beforeSig = beforeSig
        self.afterSig = afterSig
        self.beforeScreens = beforeScreens
        self.afterScreens = afterScreens
    }
}

public struct AXPermissionPayload: Codable, Sendable, Equatable {
    public let granted: Bool
    public init(granted: Bool) { self.granted = granted }
}

public struct AppLaunchPayload: Codable, Sendable, Equatable {
    public let workspaceID: UUID
    public let bundleIDHash: String
    public let timedOutAfterMs: Int

    public init(workspaceID: UUID, bundleIDHash: String, timedOutAfterMs: Int) {
        self.workspaceID = workspaceID
        self.bundleIDHash = bundleIDHash
        self.timedOutAfterMs = timedOutAfterMs
    }
}

public struct AppQuitPayload: Codable, Sendable, Equatable {
    public let workspaceID: UUID
    public let requested: Int
    public let survivorBundleIDHashes: [String]

    public init(workspaceID: UUID, requested: Int, survivorBundleIDHashes: [String]) {
        self.workspaceID = workspaceID
        self.requested = requested
        self.survivorBundleIDHashes = survivorBundleIDHashes
    }
}

// MARK: - Codable (explicit discriminator, mirrors WorkspaceTrigger)

extension DiagnosticEvent {
    private enum CodingKeys: String, CodingKey { case t, p }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let key = try c.decode(String.self, forKey: .t)
        switch key {
        case "lf":
            self = .layoutFired(try c.decode(LayoutFiredPayload.self, forKey: .p))
        case "loi":
            self = .layoutOutcomeInstant(try c.decode(LayoutOutcomePayload.self, forKey: .p))
        case "loa":
            self = .layoutOutcomeAnimated(try c.decode(AnimatedOutcomePayload.self, forKey: .p))
        case "wst":
            self = .workspaceStep(try c.decode(WorkspaceStepPayload.self, forKey: .p))
        case "trf":
            self = .triggerFired(try c.decode(TriggerFiredPayload.self, forKey: .p))
        case "trs":
            self = .triggerSuppressed(try c.decode(TriggerSuppressedPayload.self, forKey: .p))
        case "scd":
            self = .screenDiff(try c.decode(ScreenDiffPayload.self, forKey: .p))
        case "axp":
            self = .axPermissionChanged(try c.decode(AXPermissionPayload.self, forKey: .p))
        case "alt":
            self = .appLaunchTimeout(try c.decode(AppLaunchPayload.self, forKey: .p))
        case "aqs":
            self = .appQuitSurvivors(try c.decode(AppQuitPayload.self, forKey: .p))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .t, in: c,
                debugDescription: "Unknown DiagnosticEvent type \"\(key)\""
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(typeKey, forKey: .t)
        switch self {
        case .layoutFired(let p):           try c.encode(p, forKey: .p)
        case .layoutOutcomeInstant(let p):  try c.encode(p, forKey: .p)
        case .layoutOutcomeAnimated(let p): try c.encode(p, forKey: .p)
        case .workspaceStep(let p):         try c.encode(p, forKey: .p)
        case .triggerFired(let p):          try c.encode(p, forKey: .p)
        case .triggerSuppressed(let p):     try c.encode(p, forKey: .p)
        case .screenDiff(let p):            try c.encode(p, forKey: .p)
        case .axPermissionChanged(let p):   try c.encode(p, forKey: .p)
        case .appLaunchTimeout(let p):      try c.encode(p, forKey: .p)
        case .appQuitSurvivors(let p):      try c.encode(p, forKey: .p)
        }
    }
}

// MARK: - On-disk record (one JSON line = one DiagnosticEntry)

/// What a JSON Lines line looks like: `{"ts": "...", "t": "lf", "p": {...}}`.
/// `ts` is the log time (always set by the writer); the embedded
/// `EnvironmentSnapshot.ts` (when present) is the sample time.
public struct DiagnosticEntry: Codable, Sendable, Equatable {
    public let ts: Date
    public let event: DiagnosticEvent

    public init(ts: Date, event: DiagnosticEvent) {
        self.ts = ts
        self.event = event
    }

    private enum CodingKeys: String, CodingKey { case ts, t, p }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.ts = try c.decode(Date.self, forKey: .ts)
        // Re-decode using the SAME decoder so the discriminator + payload
        // resolve against the flat top-level keys.
        self.event = try DiagnosticEvent(from: decoder)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(ts, forKey: .ts)
        try event.encode(to: encoder)
    }
}
