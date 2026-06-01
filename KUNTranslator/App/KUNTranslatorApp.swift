import SwiftUI

@main
struct KUNTranslatorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            if let container = appDelegate.container {
                SettingsView(
                    settingsStore: container.settingsStore,
                    keychain: container.keychain,
                    historyRepository: container.historyRepository,
                    summaryNoteRepository: container.summaryNoteRepository,
                    permissionManager: container.permissionManager
                )
                .background(translationHost(for: container))
            } else {
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private func translationHost(for container: DependencyContainer) -> some View {
        #if HAS_APPLE_TRANSLATION && canImport(Translation)
        TranslationHostView(engine: container.appleTranslationEngine)
        #else
        TranslationHostView()
        #endif
    }
}
