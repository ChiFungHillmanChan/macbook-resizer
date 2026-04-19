import Foundation
import QuartzCore

/// Monotonic time source. Abstracted so tests can drive an `AnimationRunner`
/// deterministically with a `MockClock`.
public protocol Clock: AnyObject {
    /// Seconds since an arbitrary fixed reference (monotonic).
    func now() -> Double
}

/// Production `Clock` backed by `CACurrentMediaTime` — monotonic, suspend-aware,
/// and the same source `CVDisplayLink` callbacks reference.
public final class SystemClock: Clock {
    public init() {}
    public func now() -> Double { CACurrentMediaTime() }
}
