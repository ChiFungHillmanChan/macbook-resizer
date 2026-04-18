import ApplicationServices
import AppKit
import CoreGraphics

public final class AXWindow: WindowRef {
    public let id: CGWindowID
    public let bundleID: String?
    public let pidAccessor: pid_t
    private let element: AXUIElement

    public init(element: AXUIElement, id: CGWindowID, pid: pid_t, bundleID: String?) {
        self.element = element
        self.id = id
        self.pidAccessor = pid
        self.bundleID = bundleID
    }

    public var frame: CGRect {
        let pos = axValue(kAXPositionAttribute, type: .cgPoint) as CGPoint? ?? .zero
        let size = axValue(kAXSizeAttribute, type: .cgSize) as CGSize? ?? .zero
        return CGRect(origin: pos, size: size)
    }

    public var isMinimized: Bool {
        (axAttribute(kAXMinimizedAttribute) as? Bool) ?? false
    }

    public var isFullscreen: Bool {
        (axAttribute("AXFullScreen") as? Bool) ?? false
    }

    public func setFrame(_ rect: CGRect) throws {
        try setPosition(rect.origin)
        try setSize(rect.size)
    }

    public func minimize() throws {
        let result = AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, true as CFTypeRef)
        try throwIfFailed(result, op: "minimize")
    }

    public var axElement: AXUIElement { element }

    // MARK: - private helpers

    private func setPosition(_ point: CGPoint) throws {
        var p = point
        guard let value = AXValueCreate(.cgPoint, &p) else {
            throw AXWindowError.valueCreation
        }
        let result = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, value)
        try throwIfFailed(result, op: "setPosition")
    }

    private func setSize(_ size: CGSize) throws {
        var s = size
        guard let value = AXValueCreate(.cgSize, &s) else {
            throw AXWindowError.valueCreation
        }
        let result = AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, value)
        try throwIfFailed(result, op: "setSize")
    }

    private func axAttribute(_ name: String) -> AnyObject? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &ref) == .success else { return nil }
        return ref as AnyObject?
    }

    private func axValue<T>(_ name: String, type: AXValueType) -> T? {
        guard let raw = axAttribute(name) else { return nil }
        let axVal = raw as! AXValue
        let out = UnsafeMutablePointer<T>.allocate(capacity: 1)
        defer { out.deallocate() }
        guard AXValueGetValue(axVal, type, out) else { return nil }
        return out.pointee
    }

    private func throwIfFailed(_ result: AXError, op: String) throws {
        if result != .success {
            throw AXWindowError.apiFailed(op: op, code: Int(result.rawValue))
        }
    }
}

public enum AXWindowError: Error, Equatable {
    case valueCreation
    case apiFailed(op: String, code: Int)
}
