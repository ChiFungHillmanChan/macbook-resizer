import Carbon.HIToolbox
import Foundation
import os

public final class HotkeyManager {
    private var refs: [EventHotKeyRef] = []
    private var handlers: [UInt32: () -> Void] = [:]
    private var nextID: UInt32 = 1
    private var eventHandler: EventHandlerRef?
    private let log = Logger(subsystem: "com.scene.core", category: "hotkey")

    public init() {}

    public func register(
        id: LayoutID,
        keyCode: UInt32,
        modifiers: UInt32,
        handler: @escaping () -> Void
    ) {
        ensureEventHandlerInstalled()

        let hotKeyID = EventHotKeyID(signature: fourCharCode("SCNE"), id: nextID)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)

        guard status == noErr, let ref else {
            log.error("RegisterEventHotKey failed for \(id.rawValue, privacy: .public) status=\(status)")
            return
        }

        refs.append(ref)
        handlers[nextID] = handler
        nextID += 1
    }

    public func unregisterAll() {
        for ref in refs { UnregisterEventHotKey(ref) }
        refs.removeAll()
        handlers.removeAll()
    }

    private func ensureEventHandlerInstalled() {
        guard eventHandler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let userData = userData, let event = event else { return OSStatus(eventNotHandledErr) }
                var hkID = EventHotKeyID()
                let getStatus = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hkID
                )
                if getStatus != noErr { return getStatus }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                manager.handlers[hkID.id]?()
                return noErr
            },
            1,
            &spec,
            selfPtr,
            &eventHandler
        )
    }
}

private func fourCharCode(_ s: String) -> UInt32 {
    var result: UInt32 = 0
    for ch in s.utf8.prefix(4) {
        result = (result << 8) | UInt32(ch)
    }
    return result
}

public enum HotkeyModifiers {
    public static let cmdShift: UInt32 = UInt32(cmdKey | shiftKey)
}

public enum DefaultHotkeyKeys {
    public static let mapping: [(LayoutID, UInt32)] = [
        (.full,            UInt32(kVK_ANSI_1)),
        (.halves,          UInt32(kVK_ANSI_2)),
        (.thirds,          UInt32(kVK_ANSI_3)),
        (.quads,           UInt32(kVK_ANSI_4)),
        (.mainSide,        UInt32(kVK_ANSI_5)),
        (.leftSplitRight,  UInt32(kVK_ANSI_6)),
        (.leftRightSplit,  UInt32(kVK_ANSI_7)),
    ]
}
