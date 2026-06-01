import AppKit
import Combine

@MainActor
final class PermissionManager: ObservableObject {
    @Published private(set) var accessibilityGranted = AXIsProcessTrusted()
    @Published private(set) var screenRecordingGranted = CGPreflightScreenCaptureAccess()

    func refresh() async {
        accessibilityGranted = AXIsProcessTrusted()
        screenRecordingGranted = await Self.checkScreenRecording()
    }

    func requestAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        accessibilityGranted = AXIsProcessTrusted()
    }

    func requestScreenRecording() {
        if !CGPreflightScreenCaptureAccess() {
            CGRequestScreenCaptureAccess()
        }
        screenRecordingGranted = CGPreflightScreenCaptureAccess()
    }

    func refreshNow() {
        accessibilityGranted = AXIsProcessTrusted()
        Task {
            let screenGranted = await Self.checkScreenRecording()
            await MainActor.run {
                self.screenRecordingGranted = screenGranted
            }
        }
    }

    func openAccessibilitySettings() {
        openSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    func openScreenRecordingSettings() {
        openSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
    }

    private func openSettings(_ value: String) {
        guard let url = URL(string: value) else { return }
        NSWorkspace.shared.open(url)
    }

    private nonisolated static func checkScreenRecording() async -> Bool {
        CGPreflightScreenCaptureAccess()
    }
}
