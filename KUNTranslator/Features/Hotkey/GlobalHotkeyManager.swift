import AppKit
import Carbon
import OSLog

@MainActor
final class GlobalHotkeyManager {
    private let logger = Logger(subsystem: "com.kun.translator", category: "Hotkey")
    private var refs: [HotkeyAction: EventHotKeyRef] = [:]
    private var handlerRef: EventHandlerRef?
    private var eventMonitor: Any?
    private var callbacks: [HotkeyAction: () -> Void] = [:]
    private var lastTriggerDates: [HotkeyAction: Date] = [:]

    init() {
        installHandler()
    }

    deinit {
        for ref in refs.values {
            UnregisterEventHotKey(ref)
        }
        if let handlerRef {
            RemoveEventHandler(handlerRef)
        }
    }

    func register(settings: HotkeySettings, callbacks: [HotkeyAction: () -> Void]) {
        unregisterAll()
        self.callbacks = callbacks
        register(.translateSelection, hotkey: settings.translateSelection)
        register(.translateScreenshot, hotkey: settings.translateScreenshot)
        register(.speakSelection, hotkey: settings.speakSelection)
        installEventMonitor(settings: settings)
    }

    nonisolated static func hasConflicts(_ settings: HotkeySettings) -> Bool {
        let hotkeys = [
            settings.translateSelection,
            settings.translateScreenshot,
            settings.speakSelection
        ]
        return Set(hotkeys).count != hotkeys.count
    }

    private func unregisterAll() {
        for ref in refs.values {
            UnregisterEventHotKey(ref)
        }
        refs.removeAll()
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }

    private func register(_ action: HotkeyAction, hotkey: Hotkey) {
        var ref: EventHotKeyRef?
        let signature = Self.fourCharacterCode("KUNH")
        let hotkeyID = EventHotKeyID(signature: signature, id: action.rawValue)
        let status = RegisterEventHotKey(
            hotkey.keyCode,
            hotkey.modifiers.carbonFlags,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if status == noErr, let ref {
            refs[action] = ref
        }
        logger.info("Register \(String(describing: action), privacy: .public) \(hotkey.displayString, privacy: .public) status \(status, privacy: .public)")
        writeDiagnostic("register \(action) \(hotkey.displayString) status \(status)")
    }

    private func installHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }
                var hotkeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotkeyID
                )
                let manager = Unmanaged<GlobalHotkeyManager>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                Task { @MainActor in
                    manager.handle(id: hotkeyID.id)
                }
                return noErr
            },
            1,
            &eventType,
            selfPointer,
            &handlerRef
        )
    }

    private func installEventMonitor(settings: HotkeySettings) {
        let hotkeys: [(HotkeyAction, Hotkey)] = [
            (.translateSelection, settings.translateSelection),
            (.translateScreenshot, settings.translateScreenshot),
            (.speakSelection, settings.speakSelection)
        ]

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let match = hotkeys.first(where: { Self.matches(event: event, hotkey: $0.1) }) else { return }
            Task { @MainActor in
                self?.logger.info("NSEvent matched \(String(describing: match.0), privacy: .public)")
                self?.writeDiagnostic("nsevent matched \(match.0)")
                self?.trigger(match.0)
            }
        }
        logger.info("NSEvent global monitor installed")
        writeDiagnostic("nsevent monitor installed")
    }

    private func handle(id: UInt32) {
        guard let action = HotkeyAction(rawValue: id) else { return }
        trigger(action)
    }

    private func trigger(_ action: HotkeyAction) {
        let now = Date()
        if let last = lastTriggerDates[action], now.timeIntervalSince(last) < 0.25 {
            return
        }
        lastTriggerDates[action] = now
        logger.info("Trigger \(String(describing: action), privacy: .public)")
        writeDiagnostic("trigger \(action)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
            self?.writeDiagnostic("execute \(action)")
            self?.callbacks[action]?()
        }
    }

    private func writeDiagnostic(_ message: String) {
        DiagnosticLog.write("hotkey \(message)")
    }

    private static func matches(event: NSEvent, hotkey: Hotkey) -> Bool {
        guard UInt32(event.keyCode) == hotkey.keyCode else { return false }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return flags.contains(.command) == hotkey.modifiers.contains(.command)
            && flags.contains(.shift) == hotkey.modifiers.contains(.shift)
            && flags.contains(.option) == hotkey.modifiers.contains(.option)
            && flags.contains(.control) == hotkey.modifiers.contains(.control)
    }

    private static func fourCharacterCode(_ value: String) -> OSType {
        value.utf8.reduce(0) { result, byte in
            (result << 8) + OSType(byte)
        }
    }
}
