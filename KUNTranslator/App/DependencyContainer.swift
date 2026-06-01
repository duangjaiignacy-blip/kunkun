import AppKit

@MainActor
final class DependencyContainer {
    let settingsStore = SettingsStore()
    let keychain = KeychainStore()
    let historyRepository: HistoryRepository = SQLiteHistoryRepository()
    let summaryNoteRepository: SummaryNoteRepository = SQLiteSummaryNoteRepository()
    let permissionManager = PermissionManager()
    let hotkeyManager = GlobalHotkeyManager()
    let selectionReader: SelectionReading = AccessibilitySelectionReader()
    let speechService: SpeechService
    let translationCoordinator: TranslationCoordinator
    let ocrCoordinator: OCRCoordinator
    let overlayPresenter: OverlayPresenter
    let settingsWindowController: SettingsWindowController
    let commandRouter: CommandRouter
    let appleTranslationEngine: AppleTranslationEngine

    init() {
        speechService = SpeechService(settingsStore: settingsStore)
        appleTranslationEngine = AppleTranslationEngine()
        let openAIClient = OpenAICompatibleClient(settingsStore: settingsStore, keychain: keychain)
        let openAITranslationEngine = OpenAITranslationEngine(client: openAIClient)
        let enhancer = OpenAIEnhancer(client: openAIClient)

        translationCoordinator = TranslationCoordinator(
            apple: appleTranslationEngine,
            openAI: openAITranslationEngine,
            settingsStore: settingsStore,
            historyRepository: historyRepository
        )
        ocrCoordinator = OCRCoordinator(
            selector: ScreenRegionSelector(),
            captureService: ScreenCaptureService(),
            ocrService: OCRService()
        )
        overlayPresenter = OverlayPresenter(
            settingsStore: settingsStore,
            speechService: speechService,
            enhancer: enhancer
        )
        settingsWindowController = SettingsWindowController(
            settingsStore: settingsStore,
            keychain: keychain,
            historyRepository: historyRepository,
            summaryNoteRepository: summaryNoteRepository,
            permissionManager: permissionManager
        )
        commandRouter = CommandRouter(
            permissionManager: permissionManager,
            selectionReader: selectionReader,
            translationCoordinator: translationCoordinator,
            ocrCoordinator: ocrCoordinator,
            speechService: speechService,
            overlayPresenter: overlayPresenter,
            settingsWindowController: settingsWindowController
        )
    }

    func start() {
        settingsStore.onChange = { [weak self] _ in
            Task { @MainActor in
                self?.registerHotkeys()
            }
        }
        registerHotkeys()
        Task { await permissionManager.refresh() }
    }

    func registerHotkeys() {
        hotkeyManager.register(
            settings: settingsStore.settings.hotkeys,
            callbacks: [
                .translateSelection: { [weak self] in self?.commandRouter.translateSelection() },
                .translateScreenshot: { [weak self] in self?.commandRouter.translateScreenshot() },
                .speakSelection: { [weak self] in self?.commandRouter.speakSelection() }
            ]
        )
    }
}
