import AppKit
import SwiftUI

@MainActor
final class OverlayPresenter {
    private var panel: NSPanel?
    private let settingsStore: SettingsStore
    private let speechService: SpeechService
    private let enhancer: AIEnhancer?
    private let phoneticTranscriber = PhoneticTranscriber()

    init(settingsStore: SettingsStore, speechService: SpeechService, enhancer: AIEnhancer?) {
        self.settingsStore = settingsStore
        self.speechService = speechService
        self.enhancer = enhancer
    }

    func show(result: TranslationResult) {
        DiagnosticLog.write("overlay show result")
        let pronunciation = settingsStore.settings.speech.englishPronunciation
        let phonetic = phoneticTranscriber.transcribe(result.originalText, pronunciation: pronunciation)
            ?? phoneticTranscriber.transcribe(result.translatedText, pronunciation: pronunciation)
        let view = TranslationOverlayView(
            result: result,
            phonetic: phonetic,
            phoneticLabel: pronunciation.shortName,
            opacity: settingsStore.settings.overlayOpacity,
            onCopy: { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(result.translatedText, forType: .string) },
            onSpeak: { [weak self] in self?.speechService.speak(result.translatedText) },
            onEnhance: { [weak self] mode in
                await self?.enhance(result: result, mode: mode)
            },
            onClose: { [weak self] in self?.hide() }
        )
        show(content: view)
    }

    func show(message: String) {
        DiagnosticLog.write("overlay show message \(message)")
        show(
            content: MessageOverlayView(
                message: message,
                opacity: settingsStore.settings.overlayOpacity,
                onClose: { [weak self] in self?.hide() }
            )
        )
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
    }

    private func enhance(result: TranslationResult, mode: AIEnhancementMode) async {
        guard settingsStore.settings.aiEnhancementEnabled else {
            show(message: "AI 增强尚未开启。请在设置中打开后再试。")
            return
        }
        guard let enhancer else {
            show(message: "请先配置 DeepSeek API Key，才能使用 AI 增强。")
            return
        }
        do {
            let enhanced = try await enhancer.enhance(
                AIEnhancementRequest(
                    text: result.translatedText,
                    mode: mode,
                    targetLanguage: result.targetLanguage
                )
            )
            show(message: enhanced.text)
        } catch {
            show(message: error.localizedDescription)
        }
    }

    private func show<Content: View>(content: Content) {
        let hosting = NSHostingView(rootView: content)
        let size = hosting.fittingSize
        let mouse = NSEvent.mouseLocation
        let frame = CGRect(
            x: mouse.x + 16,
            y: max(24, mouse.y - size.height - 16),
            width: min(max(size.width, 360), 520),
            height: min(max(size.height, 180), 520)
        )

        if panel == nil {
            panel = NSPanel(
                contentRect: frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel?.isOpaque = false
            panel?.backgroundColor = .clear
            panel?.level = .floating
            panel?.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        }

        panel?.setFrame(frame, display: true)
        panel?.contentView = hosting
        panel?.alphaValue = 0
        panel?.makeKeyAndOrderFront(nil)
        DiagnosticLog.write("overlay panel ordered frame \(frame)")
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            panel?.animator().alphaValue = 1
        }

        Task { [weak self] in
            try? await Task.sleep(for: .seconds(12))
            await MainActor.run { self?.hide() }
        }
    }
}
