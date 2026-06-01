import AppKit
import SwiftUI

struct TranslationOverlayView: View {
    let result: TranslationResult
    let phonetic: String?
    let phoneticLabel: String
    let opacity: Double
    let onCopy: () -> Void
    let onSpeak: () -> Void
    let onEnhance: (AIEnhancementMode) async -> Void
    let onClose: () -> Void

    var body: some View {
        VisualEffectContainer(opacity: opacity) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(result.engine.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(action: onCopy) { Image(systemName: "doc.on.doc") }
                        .help("复制")
                    Button(action: onSpeak) { Image(systemName: "speaker.wave.2") }
                        .help("朗读")
                    Button(action: onClose) { Image(systemName: "xmark") }
                        .help("关闭")
                }
                Text(result.originalText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
                if let phonetic {
                    Label("\(phoneticLabel)音标 \(phonetic)", systemImage: "waveform")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                Divider()
                ScrollView {
                    Text(result.translatedText)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack {
                    ForEach(AIEnhancementMode.allCases) { mode in
                        Button(mode.title) {
                            Task { await onEnhance(mode) }
                        }
                    }
                    Spacer()
                }
                .buttonStyle(.bordered)
            }
            .padding(16)
        }
    }
}

struct MessageOverlayView: View {
    let message: String
    let opacity: Double
    let onClose: () -> Void

    var body: some View {
        VisualEffectContainer(opacity: opacity) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("困困翻译助手")
                        .font(.headline)
                    Spacer()
                    Button(action: onClose) { Image(systemName: "xmark") }
                        .help("关闭")
                }
                ScrollView {
                    Text(message)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
        }
    }
}

private struct VisualEffectContainer<Content: View>: NSViewRepresentable {
    let opacity: Double
    let content: Content

    init(opacity: Double, @ViewBuilder content: () -> Content) {
        self.opacity = opacity
        self.content = content()
    }

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = 14
        view.layer?.masksToBounds = true

        let hosting = NSHostingView(rootView: content)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        view.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        view.alphaValue = opacity
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.alphaValue = opacity
    }
}
