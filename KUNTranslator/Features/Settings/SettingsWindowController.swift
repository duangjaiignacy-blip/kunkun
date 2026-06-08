import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    private let settingsStore: SettingsStore
    private let keychain: KeychainStore
    private let historyRepository: HistoryRepository
    private let summaryNoteRepository: SummaryNoteRepository
    private let permissionManager: PermissionManager

    init(
        settingsStore: SettingsStore,
        keychain: KeychainStore,
        historyRepository: HistoryRepository,
        summaryNoteRepository: SummaryNoteRepository,
        permissionManager: PermissionManager
    ) {
        self.settingsStore = settingsStore
        self.keychain = keychain
        self.historyRepository = historyRepository
        self.summaryNoteRepository = summaryNoteRepository
        self.permissionManager = permissionManager
    }

    func showIfNeeded() {
        guard shouldShowOnLaunch else { return }
        show()
    }

    func show() {
        if window == nil {
            let view = SettingsView(
                settingsStore: settingsStore,
                keychain: keychain,
                historyRepository: historyRepository,
                summaryNoteRepository: summaryNoteRepository,
                permissionManager: permissionManager
            )
            let window = NSWindow(
                contentRect: CGRect(x: 0, y: 0, width: 1280, height: 760),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "困困翻译助手"
            window.minSize = CGSize(width: 1120, height: 700)
            window.contentView = NSHostingView(rootView: view)
            window.center()
            self.window = window
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private var shouldShowOnLaunch: Bool {
        if settingsStore.settings.selectedEngine == .openAI {
            let key = try? keychain.readAPIKey()
            return key?.isEmpty ?? true
        }
        return false
    }
}
