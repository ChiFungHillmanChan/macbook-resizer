import SwiftUI
import AppKit
import Carbon.HIToolbox
import SceneCore

struct HotkeyCaptureView: NSViewRepresentable {
    let onCapture: (HotkeyBinding) -> Void

    func makeNSView(context: Context) -> CaptureNSView {
        let view = CaptureNSView()
        view.onCapture = onCapture
        return view
    }
    func updateNSView(_ nsView: CaptureNSView, context: Context) {
        nsView.onCapture = onCapture
    }

    final class CaptureNSView: NSView {
        var onCapture: ((HotkeyBinding) -> Void)?
        override var acceptsFirstResponder: Bool { true }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.makeFirstResponder(self)
        }

        override func draw(_ dirtyRect: NSRect) {
            NSColor.controlAccentColor.withAlphaComponent(0.15).setFill()
            dirtyRect.fill()
            let s = "Press a key combination..."
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
            let size = (s as NSString).size(withAttributes: attrs)
            (s as NSString).draw(
                at: NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2),
                withAttributes: attrs
            )
        }

        override func keyDown(with event: NSEvent) {
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            var modifiers: Set<HotkeyModifier> = []
            if mods.contains(.command) { modifiers.insert(.command) }
            if mods.contains(.shift)   { modifiers.insert(.shift) }
            if mods.contains(.option)  { modifiers.insert(.option) }
            if mods.contains(.control) { modifiers.insert(.control) }
            // Require at least one non-shift modifier
            let nonShift = modifiers.subtracting([.shift])
            guard !nonShift.isEmpty else {
                NSSound.beep()
                return
            }
            let binding = HotkeyBinding(keyCode: UInt32(event.keyCode), modifiers: modifiers)
            onCapture?(binding)
        }
    }
}
