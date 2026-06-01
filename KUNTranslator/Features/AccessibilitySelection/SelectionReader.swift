import AppKit
import ApplicationServices
import Carbon

@MainActor
protocol SelectionReading {
    func readSelection() async throws -> String
}

@MainActor
final class AccessibilitySelectionReader: SelectionReading {
    private var activationObserver: NSObjectProtocol?
    private var lastSourceApplication: NSRunningApplication?

    init() {
        if let app = NSWorkspace.shared.frontmostApplication, !Self.isCurrentApplication(app) {
            lastSourceApplication = app
        }

        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard
                let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                !Self.isCurrentApplication(app)
            else { return }
            self?.lastSourceApplication = app
            DiagnosticLog.write("selection source app \(app.bundleIdentifier ?? app.localizedName ?? "unknown")")
        }
    }

    deinit {
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
        }
    }

    func readSelection() async throws -> String {
        if let text = readAccessibilitySelection(), !text.isBlank {
            DiagnosticLog.write("selection accessibility length \(text.count)")
            return text
        }
        if let text = await readSelectionFromClipboardFallback(), !text.isBlank {
            DiagnosticLog.write("selection clipboard length \(text.count)")
            return text
        }
        if !AXIsProcessTrusted() {
            DiagnosticLog.write("selection accessibility denied")
            throw KUNError.accessibilityDenied
        }
        DiagnosticLog.write("selection empty")
        throw KUNError.emptySelection
    }

    private func readAccessibilitySelection() -> String? {
        guard AXIsProcessTrusted() else { return nil }
        let frontmost = NSWorkspace.shared.frontmostApplication
        if let frontmost {
            DiagnosticLog.write("selection frontmost \(frontmost.bundleIdentifier ?? frontmost.localizedName ?? "unknown")")
        }

        let sourceApplication: NSRunningApplication?
        if let frontmost, !Self.isCurrentApplication(frontmost) {
            sourceApplication = frontmost
        } else {
            sourceApplication = lastSourceApplication
        }

        if let frontmost, !Self.isCurrentApplication(frontmost) {
            let systemElement = AXUIElementCreateSystemWide()
            if let text = selectedText(fromFocusedElementIn: systemElement) {
                DiagnosticLog.write("selection ax system focused length \(text.count)")
                return text
            }
        }

        guard let app = sourceApplication else { return nil }
        DiagnosticLog.write("selection target \(app.bundleIdentifier ?? app.localizedName ?? "unknown")")
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        if let text = selectedText(fromFocusedElementIn: appElement) {
            DiagnosticLog.write("selection ax system focused length \(text.count)")
            return text
        }
        return nil
    }

    private func selectedText(fromFocusedElementIn root: AXUIElement) -> String? {
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            root,
            kAXFocusedUIElementAttribute as CFString,
            &focused
        ) == .success else {
            DiagnosticLog.write("selection ax focused unavailable")
            return nil
        }

        let element = focused as! AXUIElement
        var selectedText: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            &selectedText
        )
        guard status == .success else {
            DiagnosticLog.write("selection ax selectedText status \(status.rawValue)")
            return nil
        }
        return selectedText as? String
    }

    @MainActor
    private func readSelectionFromClipboardFallback() async -> String? {
        if let frontmost = NSWorkspace.shared.frontmostApplication,
           Self.isCurrentApplication(frontmost),
           let source = lastSourceApplication {
            DiagnosticLog.write("selection reactivate \(source.bundleIdentifier ?? source.localizedName ?? "unknown")")
            source.activate(options: [.activateIgnoringOtherApps])
            try? await Task.sleep(for: .milliseconds(180))
        }

        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot(pasteboard: pasteboard)
        pasteboard.clearContents()

        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)

        let text = await waitForCopiedText(on: pasteboard)
        snapshot.restore()
        return text
    }

    @MainActor
    private func waitForCopiedText(on pasteboard: NSPasteboard) async -> String? {
        for delay in [80, 120, 180, 260, 360] {
            try? await Task.sleep(for: .milliseconds(delay))
            if let text = pasteboard.string(forType: .string), !text.isBlank {
                return text
            }
        }
        DiagnosticLog.write("selection clipboard empty")
        return nil
    }

    private static func isCurrentApplication(_ app: NSRunningApplication) -> Bool {
        app.bundleIdentifier == Bundle.main.bundleIdentifier
    }
}

private extension String {
    var isBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
