import AppKit
import SwiftUI

struct SettingsView: View {
    @Bindable var settingsStore: SettingsStore
    let keychain: KeychainStore
    let historyRepository: HistoryRepository
    let summaryNoteRepository: SummaryNoteRepository
    @ObservedObject var permissionManager: PermissionManager
    private let phoneticTranscriber = PhoneticTranscriber()

    @State private var section: WorkspaceSection = .history
    @State private var apiKey = ""
    @State private var apiKeyStatus = ""
    @State private var history: [HistoryItem] = []
    @State private var selectedHistoryID: UUID?
    @State private var searchText = ""
    @State private var historyStatus = ""
    @State private var notes: [SummaryNote] = []
    @State private var selectedNoteID: UUID?
    @State private var noteTitle = ""
    @State private var noteContent = ""
    @State private var noteSourceIDs: [UUID] = []
    @State private var noteCreatedAt = Date()
    @State private var noteStatus = ""

    var body: some View {
        ZStack {
            AppBackdrop()
            HStack(spacing: 0) {
                sidebar
                    .frame(width: 230)
                Rectangle()
                    .fill(Color(nsColor: .separatorColor).opacity(0.45))
                    .frame(width: 1)
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(nsColor: .windowBackgroundColor).opacity(0.72))
            }
        }
        .frame(minWidth: 900, minHeight: 620)
        .task {
            apiKey = (try? keychain.readAPIKey()) ?? ""
            await loadHistory()
            await loadNotes()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(
                            colors: [Color.teal.opacity(0.95), Color.blue.opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                    Image(systemName: "globe.asia.australia.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 3) {
                    Text("困困")
                        .font(.title2.weight(.semibold))
                    Text("系统级语言工作台")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 24)

            HStack(spacing: 8) {
                SidebarMetric(title: "记录", value: "\(history.count)")
                SidebarMetric(title: "笔记", value: "\(notes.count)")
            }

            VStack(spacing: 6) {
                ForEach(WorkspaceSection.allCases) { item in
                    Button {
                        withAnimation(.snappy(duration: 0.18)) {
                            section = item
                        }
                    } label: {
                        Label(item.title, systemImage: item.systemImage)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(SidebarButtonStyle(isSelected: section == item))
                }
            }

            Spacer()

            VStack(alignment: .leading, spacing: 10) {
                StatusPill(
                    title: permissionManager.accessibilityGranted ? "辅助功能" : "辅助功能未开",
                    isOn: permissionManager.accessibilityGranted
                )
                StatusPill(
                    title: permissionManager.screenRecordingGranted ? "屏幕录制" : "屏幕录制未开",
                    isOn: permissionManager.screenRecordingGranted
                )
            }

            Button {
                permissionManager.refreshNow()
            } label: {
                Label("重新检查权限", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 18)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.88))
    }

    @ViewBuilder
    private var content: some View {
        switch section {
        case .history:
            historyWorkspace
        case .notes:
            notesWorkspace
        case .settings:
            settingsWorkspace
        }
    }

    private var historyWorkspace: some View {
        VStack(spacing: 0) {
            workspaceHeader(
                title: "翻译记录",
                subtitle: "快捷键翻译和 OCR 翻译会自动沉淀到这里，方便回看、复制和生成笔记。"
            ) {
                Button {
                    Task { await loadHistory() }
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                Button(role: .destructive) {
                    Task {
                        try? await historyRepository.clear()
                        selectedHistoryID = nil
                        await loadHistory()
                    }
                } label: {
                    Label("清空", systemImage: "trash")
                }
            }
            .buttonStyle(HeaderActionButtonStyle())

            HStack(spacing: 0) {
                VStack(spacing: 12) {
                    SearchField(text: $searchText)
                        .padding(.horizontal, 18)
                        .padding(.top, 16)

                    if filteredHistory.isEmpty {
                        EmptyStateView(
                            systemImage: "clock.badge.questionmark",
                            title: "还没有翻译记录",
                            message: "在 Chrome、Safari、微信或 PDF 中选中文本后按快捷键，记录会出现在这里。"
                        )
                    } else {
                        List(selection: $selectedHistoryID) {
                            ForEach(filteredHistory) { item in
                                HistoryRow(item: item)
                                    .tag(item.id)
                                    .padding(.vertical, 5)
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                            }
                        }
                        .listStyle(.sidebar)
                        .scrollContentBackground(.hidden)
                    }
                }
                .frame(width: 390)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.24))

                Rectangle()
                    .fill(Color(nsColor: .separatorColor).opacity(0.45))
                    .frame(width: 1)

                historyDetail
            }
        }
    }

    @ViewBuilder
    private var historyDetail: some View {
        if let item = selectedHistory {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("译文")
                                .font(.title2.weight(.semibold))
                            Text("\(item.engine.displayName) / \(item.sourceLanguage) -> \(item.targetLanguage) / \(item.timestamp.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let phonetic = phonetic(for: item) {
                                Label("\(settingsStore.settings.speech.englishPronunciation.shortName)音标 \(phonetic)", systemImage: "waveform")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                        }
                        Spacer()
                        Button {
                            copy(item.translatedText)
                        } label: {
                            Label("复制译文", systemImage: "doc.on.doc")
                        }
                        Button {
                            createNote(from: [item])
                            section = .notes
                        } label: {
                            Label("生成笔记", systemImage: "note.text.badge.plus")
                        }
                    }
                    .buttonStyle(HeaderActionButtonStyle())

                    TextBlock(title: "原文", text: item.sourceText, secondary: true)
                    TextBlock(title: "翻译结果", text: item.translatedText, secondary: false)
                }
                .padding(28)
            }
        } else {
            EmptyStateView(
                systemImage: "text.magnifyingglass",
                title: "选择一条记录",
                message: "左侧选择记录后，可以复制译文或直接生成总结笔记。"
            )
        }
    }

    private var notesWorkspace: some View {
        VStack(spacing: 0) {
            workspaceHeader(
                title: "总结笔记",
                subtitle: "把最近翻译整理成可编辑笔记，用来做生词本、阅读摘要或会议资料。"
            ) {
                Button {
                    newNote()
                } label: {
                    Label("新建", systemImage: "square.and.pencil")
                }
                Button {
                    Task { await summarizeRecentHistory() }
                } label: {
                    Label("从最近记录总结", systemImage: "sparkles")
                }
                Button(role: .destructive) {
                    Task { await deleteSelectedNote() }
                } label: {
                    Label("删除", systemImage: "trash")
                }
                .disabled(selectedNoteID == nil)
            }
            .buttonStyle(HeaderActionButtonStyle())

            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    if notes.isEmpty {
                        EmptyStateView(
                            systemImage: "note.text",
                            title: "还没有笔记",
                            message: "可以手动新建，也可以从最近 10 条翻译自动生成一份总结。"
                        )
                    } else {
                        List(selection: $selectedNoteID) {
                            ForEach(notes) { note in
                                NoteRow(note: note)
                                    .tag(note.id)
                                    .padding(.vertical, 4)
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                            }
                        }
                        .listStyle(.sidebar)
                        .scrollContentBackground(.hidden)
                        .onChange(of: selectedNoteID) { _, id in
                            if let id, let note = notes.first(where: { $0.id == id }) {
                                select(note)
                            }
                        }
                    }
                }
                .frame(width: 350)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.24))

                Rectangle()
                    .fill(Color(nsColor: .separatorColor).opacity(0.45))
                    .frame(width: 1)

                noteEditor
            }
        }
    }

    private var noteEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("笔记标题", text: $noteTitle)
                .textFieldStyle(.plain)
                .font(.title2.weight(.semibold))
                .padding(.horizontal, 2)

            HStack {
                Label("\(noteSourceIDs.count) 条翻译来源", systemImage: "link")
                Text("创建于 \(noteCreatedAt.formatted(date: .abbreviated, time: .shortened))")
                Spacer()
                Text(noteStatus)
                    .foregroundStyle(.secondary)
                Button {
                    Task { await saveCurrentNote() }
                } label: {
                    Label("保存", systemImage: "checkmark.circle")
                }
                .disabled(noteTitle.trimmedForUI.isEmpty && noteContent.trimmedForUI.isEmpty)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            TextEditor(text: $noteContent)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .textBackgroundColor).opacity(0.78))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.75), lineWidth: 0.5)
                )
        }
        .padding(28)
    }

    private var settingsWorkspace: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    workspaceHeaderContent(
                        title: "设置",
                        subtitle: "配置翻译引擎、快捷键、权限、AI Key 和朗读参数。"
                    )
                    HStack(spacing: 8) {
                        StatusPill(title: settingsStore.settings.selectedEngine.displayName, isOn: true)
                        StatusPill(title: settingsStore.settings.aiEnhancementEnabled ? "AI 已开启" : "AI 已关闭", isOn: settingsStore.settings.aiEnhancementEnabled)
                        StatusPill(title: settingsStore.settings.speech.englishPronunciation.shortName, isOn: true)
                    }
                }
                .padding(.bottom, 4)

                SettingsPanel(title: "翻译") {
                    Picker("翻译引擎", selection: $settingsStore.settings.selectedEngine) {
                        ForEach(availableEngines) { engine in
                            Text(engine.displayName).tag(engine)
                        }
                    }
                    Text("当前 macOS 14 构建使用 DeepSeek / OpenAI-compatible 翻译。升级到 macOS 15+ 后可启用 Apple 翻译。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("目标语言", text: $settingsStore.settings.targetLanguage)
                    Toggle("自动检测源语言", isOn: $settingsStore.settings.autoDetectLanguage)
                }

                SettingsPanel(title: "AI") {
                    Toggle("开启 AI 增强", isOn: $settingsStore.settings.aiEnhancementEnabled)
                    HStack {
                        Button("DeepSeek V4 Flash") {
                            applyDeepSeek(model: "deepseek-v4-flash")
                        }
                        Button("DeepSeek V4 Pro") {
                            applyDeepSeek(model: "deepseek-v4-pro")
                        }
                        Button("OpenAI") {
                            settingsStore.settings.openAIModel = AppSettings.openAIModel
                            settingsStore.settings.openAIBaseURL = AppSettings.openAIBaseURL
                        }
                    }
                    TextField("模型", text: $settingsStore.settings.openAIModel)
                    TextField(
                        "接口地址",
                        text: Binding(
                            get: { settingsStore.settings.openAIBaseURL.absoluteString },
                            set: { value in
                                if let url = URL(string: value) {
                                    settingsStore.settings.openAIBaseURL = url
                                }
                            }
                        )
                    )
                    SecureField("API Key", text: $apiKey)
                    HStack {
                        Button("保存 API Key") {
                            do {
                                try keychain.saveAPIKey(apiKey)
                                apiKeyStatus = "已保存"
                            } catch {
                                apiKeyStatus = error.localizedDescription
                            }
                        }
                        Button("删除 API Key") {
                            do {
                                try keychain.deleteAPIKey()
                                apiKey = ""
                                apiKeyStatus = "已删除"
                            } catch {
                                apiKeyStatus = error.localizedDescription
                            }
                        }
                        Text(apiKeyStatus)
                            .foregroundStyle(.secondary)
                    }
                    Text("DeepSeek 接口地址填 https://api.deepseek.com 即可，程序会自动请求 /chat/completions。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                SettingsPanel(title: "外观与快捷键") {
                    Picker("外观", selection: $settingsStore.settings.appearance) {
                        ForEach(AppAppearance.allCases) { appearance in
                            Text(appearance.displayName).tag(appearance)
                        }
                    }
                    Slider(value: $settingsStore.settings.overlayOpacity, in: 0.5...1.0) {
                        Text("悬浮窗透明度")
                    }
                    HotkeyRecorderRow(title: "翻译选中文本", hotkey: $settingsStore.settings.hotkeys.translateSelection)
                    HotkeyRecorderRow(title: "截图 OCR 翻译", hotkey: $settingsStore.settings.hotkeys.translateScreenshot)
                    HotkeyRecorderRow(title: "朗读选中文本", hotkey: $settingsStore.settings.hotkeys.speakSelection)
                    if GlobalHotkeyManager.hasConflicts(settingsStore.settings.hotkeys) {
                        Text("快捷键不能重复。")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                SettingsPanel(title: "权限") {
                    PermissionStatusRow(
                        title: "辅助功能",
                        isGranted: permissionManager.accessibilityGranted,
                        actionTitle: "打开辅助功能设置",
                        action: {
                            permissionManager.requestAccessibility()
                            permissionManager.openAccessibilitySettings()
                        }
                    )
                    PermissionStatusRow(
                        title: "屏幕录制",
                        isGranted: permissionManager.screenRecordingGranted,
                        actionTitle: "打开屏幕录制设置",
                        action: {
                            permissionManager.requestScreenRecording()
                            permissionManager.openScreenRecordingSettings()
                        }
                    )
                    Button("重新检查权限") {
                        permissionManager.refreshNow()
                    }
                    Text("如果系统设置里已经勾选但这里仍显示未生效，请先删除旧条目，再把 /Applications/KUNTranslator.app 重新添加进去。调试版重新签名后，macOS 可能会把旧授权视为失效。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                SettingsPanel(title: "朗读") {
                    Picker("英语发音", selection: $settingsStore.settings.speech.englishPronunciation) {
                        ForEach(EnglishPronunciation.allCases) { pronunciation in
                            Text(pronunciation.displayName).tag(pronunciation)
                        }
                    }
                    Slider(value: $settingsStore.settings.speech.rate, in: 0.1...0.7) { Text("语速") }
                    Slider(value: $settingsStore.settings.speech.pitch, in: 0.5...2.0) { Text("音调") }
                    Slider(value: $settingsStore.settings.speech.volume, in: 0.1...1.0) { Text("音量") }
                    Text("音标和朗读会跟随这里的美式/英式选择。若手动指定系统 voiceIdentifier，则优先使用指定声音。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(28)
        }
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.42))
    }

    private func workspaceHeader<Actions: View>(
        title: String,
        subtitle: String,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        HStack(alignment: .center, spacing: 16) {
            workspaceHeaderContent(title: title, subtitle: subtitle)
            Spacer()
            actions()
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(nsColor: .separatorColor).opacity(0.5))
                .frame(height: 1)
        }
    }

    private func workspaceHeaderContent(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.title.weight(.semibold))
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    private var filteredHistory: [HistoryItem] {
        let query = searchText.trimmedForUI
        guard !query.isEmpty else { return history }
        return history.filter {
            $0.sourceText.localizedCaseInsensitiveContains(query)
                || $0.translatedText.localizedCaseInsensitiveContains(query)
        }
    }

    private var selectedHistory: HistoryItem? {
        if let selectedHistoryID,
           let item = history.first(where: { $0.id == selectedHistoryID }) {
            return item
        }
        return filteredHistory.first
    }

    private func phonetic(for item: HistoryItem) -> String? {
        let pronunciation = settingsStore.settings.speech.englishPronunciation
        return phoneticTranscriber.transcribe(item.sourceText, pronunciation: pronunciation)
            ?? phoneticTranscriber.transcribe(item.translatedText, pronunciation: pronunciation)
    }

    private func loadHistory() async {
        do {
            history = try await historyRepository.recent(limit: 200)
            if selectedHistoryID == nil {
                selectedHistoryID = history.first?.id
            }
            historyStatus = ""
        } catch {
            historyStatus = error.localizedDescription
        }
    }

    private func loadNotes(selecting noteID: UUID? = nil) async {
        do {
            notes = try await summaryNoteRepository.recent(limit: 100)
            if let noteID,
               let note = notes.first(where: { $0.id == noteID }) {
                select(note)
            } else if selectedNoteID == nil,
                      let note = notes.first {
                select(note)
            } else if notes.isEmpty {
                newNote()
            }
            noteStatus = ""
        } catch {
            noteStatus = error.localizedDescription
        }
    }

    private func newNote() {
        selectedNoteID = nil
        noteTitle = "新笔记"
        noteContent = ""
        noteSourceIDs = []
        noteCreatedAt = Date()
        noteStatus = "未保存"
    }

    private func select(_ note: SummaryNote) {
        selectedNoteID = note.id
        noteTitle = note.title
        noteContent = note.content
        noteSourceIDs = note.sourceHistoryIDs
        noteCreatedAt = note.createdAt
        noteStatus = ""
    }

    private func createNote(from items: [HistoryItem]) {
        let now = Date()
        selectedNoteID = nil
        noteTitle = "翻译总结 \(now.formatted(date: .abbreviated, time: .shortened))"
        noteContent = makeSummaryContent(from: items)
        noteSourceIDs = items.map(\.id)
        noteCreatedAt = now
        noteStatus = "已生成草稿"
    }

    private func summarizeRecentHistory() async {
        let items = (try? await historyRepository.recent(limit: 10)) ?? []
        guard !items.isEmpty else {
            noteStatus = "没有可总结的翻译记录"
            return
        }
        createNote(from: items)
    }

    private func saveCurrentNote() async {
        let title = noteTitle.trimmedForUI.isEmpty ? "未命名笔记" : noteTitle.trimmedForUI
        let id = selectedNoteID ?? UUID()
        let createdAt = selectedNoteID == nil ? Date() : noteCreatedAt
        let note = SummaryNote(
            id: id,
            title: title,
            content: noteContent.trimmedForUI,
            sourceHistoryIDs: noteSourceIDs,
            createdAt: createdAt,
            updatedAt: Date()
        )

        do {
            try await summaryNoteRepository.save(note)
            selectedNoteID = id
            noteCreatedAt = createdAt
            noteStatus = "已保存"
            await loadNotes(selecting: id)
        } catch {
            noteStatus = error.localizedDescription
        }
    }

    private func deleteSelectedNote() async {
        guard let selectedNoteID else { return }
        do {
            try await summaryNoteRepository.delete(id: selectedNoteID)
            self.selectedNoteID = nil
            await loadNotes()
        } catch {
            noteStatus = error.localizedDescription
        }
    }

    private func makeSummaryContent(from items: [HistoryItem]) -> String {
        var lines: [String] = [
            "# 翻译总结",
            "",
            "来源：最近 \(items.count) 条翻译记录",
            ""
        ]

        for (index, item) in items.enumerated() {
            lines.append("\(index + 1). \(item.translatedText.trimmedForUI)")
            lines.append("   原文：\(item.sourceText.trimmedForUI)")
        }

        lines.append("")
        lines.append("可补充：关键词、行动项、上下文备注。")
        return lines.joined(separator: "\n")
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func applyDeepSeek(model: String) {
        settingsStore.settings.selectedEngine = .openAI
        settingsStore.settings.aiEnhancementEnabled = true
        settingsStore.settings.openAIModel = model
        settingsStore.settings.openAIBaseURL = AppSettings.deepSeekBaseURL
    }

    private var availableEngines: [TranslationEngineKind] {
#if HAS_APPLE_TRANSLATION
        TranslationEngineKind.allCases.filter { $0 != .mock }
#else
        [.openAI]
#endif
    }
}

private enum WorkspaceSection: CaseIterable, Identifiable {
    case history
    case notes
    case settings

    var id: Self { self }

    var title: String {
        switch self {
        case .history: "翻译记录"
        case .notes: "总结笔记"
        case .settings: "设置"
        }
    }

    var systemImage: String {
        switch self {
        case .history: "text.book.closed"
        case .notes: "note.text"
        case .settings: "gearshape"
        }
    }
}

private struct AppBackdrop: View {
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color(nsColor: .windowBackgroundColor)
            LinearGradient(
                colors: [
                    Color.teal.opacity(0.10),
                    Color.blue.opacity(0.05),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .center
            )
            .ignoresSafeArea()
            Rectangle()
                .fill(Color(nsColor: .separatorColor).opacity(0.18))
                .frame(width: 1)
                .padding(.trailing, 22)
        }
    }
}

private struct SidebarMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.headline.weight(.semibold))
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .textBackgroundColor).opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 0.5)
        )
    }
}

private struct StatusPill: View {
    let title: String
    let isOn: Bool

    var body: some View {
        Label(title, systemImage: isOn ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
            .font(.caption.weight(.medium))
            .foregroundStyle(isOn ? .green : .orange)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill((isOn ? Color.green : Color.orange).opacity(0.11))
            )
    }
}

private struct SidebarButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(isSelected ? .semibold : .regular))
            .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.clear)
            )
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(isSelected ? Color.accentColor : Color.clear)
                    .frame(width: 3, height: 18)
                    .padding(.leading, 2)
            }
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

private struct HeaderActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .textBackgroundColor).opacity(configuration.isPressed ? 0.56 : 0.78))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.65), lineWidth: 0.5)
            )
    }
}

private struct HistoryRow: View {
    let item: HistoryItem

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.accentColor.opacity(0.72))
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(item.translatedText)
                        .font(.callout.weight(.semibold))
                        .lineLimit(2)
                    Spacer()
                    Text(item.engine.displayName)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Text(item.sourceText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(item.timestamp.formatted(date: .numeric, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .textBackgroundColor).opacity(0.58))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(0.36), lineWidth: 0.5)
        )
    }
}

private struct NoteRow: View {
    let note: SummaryNote

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(note.title)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
            Text(note.content)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            HStack {
                Label("\(note.sourceHistoryIDs.count)", systemImage: "link")
                Spacer()
                Text(note.updatedAt.formatted(date: .numeric, time: .shortened))
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .textBackgroundColor).opacity(0.58))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(0.36), lineWidth: 0.5)
        )
    }
}

private struct TextBlock: View {
    let title: String
    let text: String
    let secondary: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Image(systemName: secondary ? "text.quote" : "sparkle.magnifyingglass")
                    .foregroundStyle(.secondary)
            }
            Text(text)
                .font(.body)
                .foregroundStyle(secondary ? .secondary : .primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: secondary ? .controlBackgroundColor : .textBackgroundColor).opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 0.5)
        )
    }
}

private struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.18))
    }
}

private struct SearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("搜索原文或译文", text: $text)
                .textFieldStyle(.plain)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .textBackgroundColor).opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(0.55), lineWidth: 0.5)
        )
    }
}

private struct SettingsPanel<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline.weight(.semibold))
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .textFieldStyle(.roundedBorder)
            .controlSize(.regular)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.58))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(0.42), lineWidth: 0.5)
        )
    }
}

private struct PermissionStatusRow: View {
    let title: String
    let isGranted: Bool
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack {
            Label(isGranted ? "\(title)：已生效" : "\(title)：未生效", systemImage: isGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(isGranted ? .green : .orange)
            Spacer()
            Button(actionTitle, action: action)
        }
    }
}

private struct HotkeyRecorderRow: View {
    let title: String
    @Binding var hotkey: Hotkey

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            HotkeyRecorder(hotkey: $hotkey)
                .frame(width: 120, height: 30)
        }
    }
}

private struct HotkeyRecorder: NSViewRepresentable {
    @Binding var hotkey: Hotkey

    func makeNSView(context: Context) -> RecorderButton {
        let button = RecorderButton()
        button.onChange = { hotkey = $0 }
        button.hotkey = hotkey
        return button
    }

    func updateNSView(_ nsView: RecorderButton, context: Context) {
        nsView.hotkey = hotkey
    }
}

private final class RecorderButton: NSButton {
    var onChange: ((Hotkey) -> Void)?
    var hotkey: Hotkey = HotkeySettings.default.translateSelection {
        didSet {
            title = isRecording ? "按下快捷键" : hotkey.displayString
        }
    }
    private var isRecording = false

    init() {
        super.init(frame: .zero)
        bezelStyle = .rounded
        setButtonType(.momentaryPushIn)
        target = self
        action = #selector(startRecording)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    @objc private func startRecording() {
        isRecording = true
        title = "按下快捷键"
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }
        let modifiers = HotkeyModifiers(event.modifierFlags)
        guard !modifiers.isEmpty else { return }
        hotkey = Hotkey(keyCode: UInt32(event.keyCode), modifiers: modifiers)
        onChange?(hotkey)
        isRecording = false
    }
}

private extension HotkeyModifiers {
    init(_ flags: NSEvent.ModifierFlags) {
        var modifiers: HotkeyModifiers = []
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.control) { modifiers.insert(.control) }
        self = modifiers
    }
}

private extension String {
    var trimmedForUI: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
