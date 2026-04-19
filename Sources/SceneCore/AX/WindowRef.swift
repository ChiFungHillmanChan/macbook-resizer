import CoreGraphics

public protocol WindowRef: AnyObject {
    var id: CGWindowID { get }
    var bundleID: String? { get }
    var frame: CGRect { get }
    var isMinimized: Bool { get }
    var isFullscreen: Bool { get }
    func setFrame(_ rect: CGRect) throws
    func minimize() throws
}
