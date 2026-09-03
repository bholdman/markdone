import AppKit
import Carbon.HIToolbox

/// Registers system-wide hotkeys via the Carbon Hot Key API so MarkDone can be
/// summoned even when it isn't the frontmost app. Carbon's RegisterEventHotKey does
/// not require Accessibility permissions, unlike a global NSEvent monitor.
final class HotKeyManager {
    static let shared = HotKeyManager()

    private var handlers: [UInt32: () -> Void] = [:]
    private var registeredRefs: [EventHotKeyRef?] = []
    private var eventHandler: EventHandlerRef?
    private var nextID: UInt32 = 1
    private let signature: OSType = 0x4D4B444E // 'MKDN'

    private init() {}

    /// Install the default shortcuts. Call once at launch.
    func registerDefaults(newDocument: @escaping () -> Void,
                          newFromClipboard: @escaping () -> Void) {
        installEventHandlerIfNeeded()
        // ⌥⌘M — new empty document
        register(keyCode: UInt32(kVK_ANSI_M),
                 modifiers: UInt32(optionKey | cmdKey),
                 action: newDocument)
        // ⌥⌘V — new document pre-filled from the clipboard
        register(keyCode: UInt32(kVK_ANSI_V),
                 modifiers: UInt32(optionKey | cmdKey),
                 action: newFromClipboard)
    }

    private func register(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        let id = nextID
        nextID += 1
        handlers[id] = action

        let hotKeyID = EventHotKeyID(signature: signature, id: id)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID,
                                         GetApplicationEventTarget(), 0, &ref)
        if status == noErr {
            registeredRefs.append(ref)
        } else {
            NSLog("MarkDone: failed to register hotkey \(id) (status \(status))")
        }
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return noErr }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                           EventParamType(typeEventHotKeyID), nil,
                                           MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            if status == noErr {
                manager.fire(id: hotKeyID.id)
            }
            return noErr
        }, 1, &spec, selfPtr, &eventHandler)
    }

    private func fire(id: UInt32) {
        guard let action = handlers[id] else { return }
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            action()
        }
    }
}
