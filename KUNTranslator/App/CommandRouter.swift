import Foundation

@MainActor
final class CommandRouter {
    private let permissionManager: PermissionManager
    private let selectionReader: SelectionReading
    private let translationCoordinator: TranslationCoordinator
    private let ocrCoordinator: OCRCoordinator
    private let speechService: SpeechService
    private let overlayPresenter: OverlayPresenter
    private let settingsWindowController: SettingsWindowController

    init(
        permissionManager: PermissionManager,
        selectionReader: SelectionReading,
        translationCoordinator: TranslationCoordinator,
        ocrCoordinator: OCRCoordinator,
        speechService: SpeechService,
        overlayPresenter: OverlayPresenter,
        settingsWindowController: SettingsWindowController
    ) {
        self.permissionManager = permissionManager
        self.selectionReader = selectionReader
        self.translationCoordinator = translationCoordinator
        self.ocrCoordinator = ocrCoordinator
        self.speechService = speechService
        self.overlayPresenter = overlayPresenter
        self.settingsWindowController = settingsWindowController
    }

    func translateSelection() {
        DiagnosticLog.write("command translateSelection start")
        Task {
            do {
                let text = try await selectionReader.readSelection()
                DiagnosticLog.write("command selection length \(text.count)")
                let result = try await translationCoordinator.translate(text)
                DiagnosticLog.write("command translation success")
                overlayPresenter.show(result: result)
            } catch {
                DiagnosticLog.write("command translateSelection error \(error.localizedDescription)")
                handle(error)
            }
        }
    }

    func translateScreenshot() {
        DiagnosticLog.write("command translateScreenshot start")
        Task {
            await permissionManager.refresh()
            DiagnosticLog.write("command screenRecordingGranted \(permissionManager.screenRecordingGranted)")
            guard permissionManager.screenRecordingGranted else {
                DiagnosticLog.write("command translateScreenshot screenRecordingDenied")
                handle(KUNError.screenRecordingDenied)
                permissionManager.openScreenRecordingSettings()
                return
            }
            do {
                let text = try await ocrCoordinator.captureText()
                DiagnosticLog.write("command ocr text length \(text.count)")
                let result = try await translationCoordinator.translate(text)
                DiagnosticLog.write("command ocr translation success")
                overlayPresenter.show(result: result)
            } catch {
                DiagnosticLog.write("command translateScreenshot error \(error.localizedDescription)")
                handle(error)
            }
        }
    }

    func speakSelection() {
        DiagnosticLog.write("command speakSelection start")
        Task {
            do {
                let text = try await selectionReader.readSelection()
                DiagnosticLog.write("command speak selection length \(text.count)")
                speechService.speak(text)
                DiagnosticLog.write("command speakSelection success")
            } catch {
                DiagnosticLog.write("command speakSelection error \(error.localizedDescription)")
                handle(error)
            }
        }
    }

    private func handle(_ error: Error) {
        if let kunError = error as? KUNError {
            switch kunError {
            case .accessibilityDenied:
                DiagnosticLog.write("command handle accessibilityDenied")
                permissionManager.requestAccessibility()
                permissionManager.openAccessibilitySettings()
                overlayPresenter.show(message: "辅助功能权限未生效。已打开系统设置，请删除旧的困困翻译助手条目后重新添加 /Applications/KUNTranslator.app，并确认开关已开启。")
                settingsWindowController.show()
                return
            case .missingAPIKey:
                DiagnosticLog.write("command handle missingAPIKey")
                overlayPresenter.show(message: "还没有配置 DeepSeek API Key。已打开设置窗口，请在“AI”页粘贴密钥。")
                settingsWindowController.show()
                return
            default:
                break
            }
        }
        overlayPresenter.show(message: error.localizedDescription)
    }
}
