import Foundation

/// Sync, fast log surface used by orchestration code. The default
/// implementation is `.noop` — services constructed without a real sink
/// (tests, sandboxed initializers) silently drop events. Production
/// SceneApp wires `DiagnosticEventLogger` (an `@MainActor` adapter) which
/// pushes onto an `EventLog` ring buffer + `DiagnosticWriter` actor.
public protocol DiagnosticSink: Sendable {
    func log(_ event: DiagnosticEvent)
}

public struct NoopDiagnosticSink: DiagnosticSink {
    public init() {}
    public func log(_ event: DiagnosticEvent) {}
}

extension DiagnosticSink where Self == NoopDiagnosticSink {
    public static var noop: NoopDiagnosticSink { NoopDiagnosticSink() }
}
