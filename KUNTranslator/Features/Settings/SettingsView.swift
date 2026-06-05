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
    @State private var feishuWebhookURL = ""
    @State private var feishuStatus = ""
    @State private var isTestingFeishu = false
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
    @State private var serviceMode: ServiceMode = .textTranslation
    @State private var selectedService: TranslationServiceKind = .deepSeek

    var body: some View {
        ZStack {
            AppBackdrop()
            HStack(spacing: 0) {
                sidebar
                    .frame(width: 250)
                Rectangle()
                    .fill(KUNPalette.line.opacity(0.72))
                    .frame(width: 1)
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(KUNPalette.canvas.opacity(0.78))
            }
        }
        .frame(minWidth: 1040, minHeight: 680)
        .task {
            await loadStoredSecrets()
            await loadHistory()
            await loadNotes()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(
                            colors: [KUNPalette.mint, KUNPalette.sky],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                    Image(systemName: "globe.asia.australia.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(KUNPalette.ink)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 3) {
                    Text("困困翻译")
                        .font(.title2.weight(.semibold))
                    Text("Translate anything")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 24)

            HStack(spacing: 8) {
                SidebarMetric(title: "记录", value: "\(history.count)", systemImage: "text.book.closed")
                SidebarMetric(title: "笔记", value: "\(notes.count)", systemImage: "note.text")
            }

            VStack(alignment: .leading, spacing: 16) {
                ForEach(SidebarGroup.allCases) { group in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(group.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .padding(.horizontal, 14)
                        ForEach(group.sections) { item in
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
                }
            }

            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                PermissionMiniCard(
                    title: "辅助功能",
                    message: permissionManager.accessibilityGranted ? "已生效" : "需要授权",
                    isGranted: permissionManager.accessibilityGranted
                )
                PermissionMiniCard(
                    title: "屏幕录制",
                    message: permissionManager.screenRecordingGranted ? "已生效" : "需要授权",
                    isGranted: permissionManager.screenRecordingGranted
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
        .background(KUNPalette.sidebar)
    }

    @ViewBuilder
    private var content: some View {
        switch section {
        case .translation:
            translationWorkspace
        case .services:
            servicesWorkspace
        case .ocr:
            ocrWorkspace
        case .history:
            historyWorkspace
        case .notes:
            notesWorkspace
        case .general:
            generalWorkspace
        }
    }

    private var historyWorkspace: some View {
        VStack(spacing: 0) {
            HomeHeroHeader(
                historyCount: history.count,
                noteCount: notes.count,
                engine: settingsStore.settings.selectedEngine.displayName,
                accessibilityOn: permissionManager.accessibilityGranted,
                screenOn: permissionManager.screenRecordingGranted,
                onRefresh: { Task { await loadHistory() } },
                onClear: {
                    Task {
                        try? await historyRepository.clear()
                        selectedHistoryID = nil
                        await loadHistory()
                    }
                },
                onOpenOCR: { section = .ocr },
                onOpenSpeech: { section = .general },
                onOpenAI: { section = .services }
            )

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
                .background(KUNPalette.surface.opacity(0.34))

                Rectangle()
                    .fill(KUNPalette.line.opacity(0.72))
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
                            HStack(spacing: 8) {
                                MetaChip(title: item.engine.displayName, systemImage: "bolt.horizontal")
                                MetaChip(title: "\(item.sourceLanguage) -> \(item.targetLanguage)", systemImage: "arrow.left.arrow.right")
                                MetaChip(title: item.timestamp.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                            }
                            if let phonetic = phonetic(for: item) {
                                MetaChip(title: "\(settingsStore.settings.speech.englishPronunciation.shortName)音标 \(phonetic)", systemImage: "waveform")
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
                subtitle: "把翻译沉淀成可编辑的阅读摘要和复习材料。"
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
                .background(KUNPalette.surface.opacity(0.34))

                Rectangle()
                    .fill(KUNPalette.line.opacity(0.72))
                    .frame(width: 1)

                noteEditor
            }
        }
    }

    private var noteEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("笔记标题", text: $noteTitle)
                .textFieldStyle(.plain)
                .font(.title.weight(.semibold))
                .padding(.horizontal, 4)

            HStack {
                MetaChip(title: "\(noteSourceIDs.count) 条来源", systemImage: "link")
                MetaChip(title: noteCreatedAt.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
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
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(KUNPalette.surface.opacity(0.82))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.white.opacity(0.78), lineWidth: 0.8)
                )
        }
        .padding(30)
    }

    private var translationWorkspace: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                workspaceHero(
                    title: "翻译设置",
                    subtitle: "配置目标语言、翻译引擎、AI 增强和全局划词行为。",
                    systemImage: "character.bubble",
                    badges: [
                        settingsStore.settings.selectedEngine.displayName,
                        settingsStore.settings.targetLanguage,
                        settingsStore.settings.aiEnhancementEnabled ? "AI 已开启" : "AI 已关闭"
                    ]
                )

                LazyVGrid(columns: settingsColumns, alignment: .leading, spacing: 16) {
                    SettingsPanel(title: "基础翻译", systemImage: "globe") {
                        Picker("翻译引擎", selection: $settingsStore.settings.selectedEngine) {
                            ForEach(availableEngines) { engine in
                                Text(engine.displayName).tag(engine)
                            }
                        }
                        TextField("目标语言", text: $settingsStore.settings.targetLanguage)
                        Toggle("自动检测源语言", isOn: $settingsStore.settings.autoDetectLanguage)
                        Text("建议使用 zh-Hans、en、ja 等标准语言代码；开启自动检测后，系统会根据原文自动判断源语言。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    SettingsPanel(title: "AI 增强", systemImage: "sparkles") {
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
                        Text("AI 增强用于润色、解释、总结和改写；基础翻译仍由当前服务配置决定。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    SettingsPanel(title: "划词快捷键", systemImage: "keyboard") {
                        HotkeyRecorderRow(title: "翻译选中文本", hotkey: $settingsStore.settings.hotkeys.translateSelection)
                        HotkeyRecorderRow(title: "朗读选中文本", hotkey: $settingsStore.settings.hotkeys.speakSelection)
                        if GlobalHotkeyManager.hasConflicts(settingsStore.settings.hotkeys) {
                            Text("快捷键不能重复。")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .padding(28)
        }
        .background(KUNPalette.canvas.opacity(0.78))
    }

    private var servicesWorkspace: some View {
        VStack(spacing: 0) {
            workspaceHeader(
                title: "服务",
                subtitle: "翻译功能的核心服务支持配置，下方开启的服务将被使用。"
            ) {
                Button {
                    openHelp()
                } label: {
                    Label("使用教程", systemImage: "questionmark.circle")
                }
            }
            .buttonStyle(HeaderActionButtonStyle())

            VStack(alignment: .leading, spacing: 18) {
                Picker("服务类型", selection: $serviceMode) {
                    ForEach(ServiceMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 520)
                .labelsHidden()

                HStack(alignment: .top, spacing: 22) {
                    serviceList
                        .frame(width: 360)

                    serviceDetail
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .padding(28)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(KUNPalette.canvas.opacity(0.78))
        }
    }

    @ViewBuilder
    private var serviceList: some View {
        switch serviceMode {
        case .textTranslation:
            VStack(spacing: 0) {
                ForEach(TranslationServiceKind.allCases) { service in
                    Button {
                        selectedService = service
                    } label: {
                        ServiceListRow(
                            title: service.title,
                            subtitle: service.subtitle,
                            systemImage: service.systemImage,
                            isBuiltIn: service.isBuiltIn,
                            isOn: serviceIsOn(service),
                            isSelected: selectedService == service,
                            tone: service.tone
                        )
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
            .serviceListBackground()
        case .textRecognition:
            VStack(spacing: 0) {
                ServiceListRow(
                    title: "Vision OCR",
                    subtitle: "本机文字识别",
                    systemImage: "viewfinder",
                    isBuiltIn: true,
                    isOn: true,
                    isSelected: true,
                    tone: .sky
                )
                ServiceListRow(
                    title: "ScreenCaptureKit",
                    subtitle: "区域截图捕获",
                    systemImage: "rectangle.dashed",
                    isBuiltIn: true,
                    isOn: permissionManager.screenRecordingGranted,
                    isSelected: false,
                    tone: .mint
                )
                Spacer(minLength: 0)
            }
            .serviceListBackground()
        case .speechSynthesis:
            VStack(spacing: 0) {
                ServiceListRow(
                    title: "系统语音合成",
                    subtitle: settingsStore.settings.speech.englishPronunciation.displayName,
                    systemImage: "speaker.wave.2",
                    isBuiltIn: true,
                    isOn: true,
                    isSelected: true,
                    tone: .lemon
                )
                Spacer(minLength: 0)
            }
            .serviceListBackground()
        }
    }

    @ViewBuilder
    private var serviceDetail: some View {
        switch serviceMode {
        case .textTranslation:
            TranslationServiceDetail(
                selectedService: selectedService,
                settingsStore: settingsStore,
                apiKey: $apiKey,
                apiKeyStatus: $apiKeyStatus,
                feishuWebhookURL: $feishuWebhookURL,
                feishuStatus: $feishuStatus,
                isTestingFeishu: isTestingFeishu,
                keychain: keychain,
                saveAPIKey: saveAPIKey,
                deleteAPIKey: deleteAPIKey,
                applyDeepSeek: applyDeepSeek,
                testFeishuConnection: { Task { await testFeishuConnection() } }
            )
        case .textRecognition:
            SettingsDetailSurface(title: "文本识别", subtitle: "截图 OCR 使用 macOS 原生 ScreenCaptureKit 和 Vision。") {
                PermissionStatusRow(
                    title: "屏幕录制",
                    isGranted: permissionManager.screenRecordingGranted,
                    actionTitle: "打开屏幕录制设置",
                    action: {
                        permissionManager.requestScreenRecording()
                        permissionManager.openScreenRecordingSettings()
                    }
                )
                Divider()
                HotkeyRecorderRow(title: "截图 OCR 翻译", hotkey: $settingsStore.settings.hotkeys.translateScreenshot)
                Text("OCR 只会识别你框选的屏幕区域。授权后无需重启，点击重新检查权限即可刷新状态。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .speechSynthesis:
            SettingsDetailSurface(title: "语音合成", subtitle: "朗读使用 AVSpeechSynthesizer，本机完成，不需要上传音频。") {
                Picker("英语发音", selection: $settingsStore.settings.speech.englishPronunciation) {
                    ForEach(EnglishPronunciation.allCases) { pronunciation in
                        Text(pronunciation.displayName).tag(pronunciation)
                    }
                }
                Slider(value: $settingsStore.settings.speech.rate, in: 0.1...0.7) { Text("语速") }
                Slider(value: $settingsStore.settings.speech.pitch, in: 0.5...2.0) { Text("音调") }
                Slider(value: $settingsStore.settings.speech.volume, in: 0.1...1.0) { Text("音量") }
                Text("音标和朗读会跟随美式/英式选择。若手动指定系统 voiceIdentifier，则优先使用指定声音。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var ocrWorkspace: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                workspaceHero(
                    title: "OCR 设置",
                    subtitle: "管理截图识别、屏幕录制权限和 OCR 翻译快捷键。",
                    systemImage: "viewfinder.rectangular",
                    badges: [
                        permissionManager.screenRecordingGranted ? "屏幕录制已生效" : "屏幕录制未生效",
                        "Vision OCR"
                    ]
                )

                LazyVGrid(columns: settingsColumns, alignment: .leading, spacing: 16) {
                    SettingsPanel(title: "截图识别", systemImage: "rectangle.dashed") {
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
                        Text("用于框选屏幕区域后进行 OCR。当前实现不会持续录屏，只在你触发 OCR 时捕获选区图像。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    SettingsPanel(title: "OCR 快捷键", systemImage: "keyboard") {
                        HotkeyRecorderRow(title: "截图 OCR 翻译", hotkey: $settingsStore.settings.hotkeys.translateScreenshot)
                    }
                }
            }
            .padding(28)
        }
        .background(KUNPalette.canvas.opacity(0.78))
    }

    private var generalWorkspace: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                workspaceHero(
                    title: "通用设置",
                    subtitle: "管理外观、权限、历史容量和系统级运行状态。",
                    systemImage: "gearshape.2",
                    badges: [
                        settingsStore.settings.appearance.displayName,
                        "\(settingsStore.settings.maxHistoryItems) 条历史"
                    ]
                )

                LazyVGrid(columns: settingsColumns, alignment: .leading, spacing: 16) {
                    SettingsPanel(title: "外观", systemImage: "paintbrush") {
                        Picker("外观", selection: $settingsStore.settings.appearance) {
                            ForEach(AppAppearance.allCases) { appearance in
                                Text(appearance.displayName).tag(appearance)
                            }
                        }
                        Slider(value: $settingsStore.settings.overlayOpacity, in: 0.5...1.0) {
                            Text("悬浮窗透明度")
                        }
                    }

                    SettingsPanel(title: "权限", systemImage: "lock.shield") {
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
                    }

                    SettingsPanel(title: "朗读", systemImage: "speaker.wave.2") {
                        Picker("英语发音", selection: $settingsStore.settings.speech.englishPronunciation) {
                            ForEach(EnglishPronunciation.allCases) { pronunciation in
                                Text(pronunciation.displayName).tag(pronunciation)
                            }
                        }
                        Slider(value: $settingsStore.settings.speech.rate, in: 0.1...0.7) { Text("语速") }
                        Slider(value: $settingsStore.settings.speech.pitch, in: 0.5...2.0) { Text("音调") }
                        Slider(value: $settingsStore.settings.speech.volume, in: 0.1...1.0) { Text("音量") }
                    }

                    SettingsPanel(title: "系统状态", systemImage: "waveform.path.ecg") {
                        StatusLine(title: "辅助功能", isOn: permissionManager.accessibilityGranted)
                        StatusLine(title: "屏幕录制", isOn: permissionManager.screenRecordingGranted)
                        StatusLine(title: "AI 增强", isOn: settingsStore.settings.aiEnhancementEnabled)
                        Text("如果系统设置里已经勾选但仍显示未生效，请删除旧条目，再重新添加 /Applications/KUNTranslator.app。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(28)
        }
        .background(KUNPalette.canvas.opacity(0.78))
    }

    private func workspaceHero(title: String, subtitle: String, systemImage: String, badges: [String]) -> some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(KUNPalette.mint.opacity(0.54))
                Image(systemName: systemImage)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(KUNPalette.ink)
            }
            .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 7) {
                workspaceHeaderContent(title: title, subtitle: subtitle)
                HStack(spacing: 8) {
                    ForEach(badges, id: \.self) { badge in
                        MetaChip(title: badge, systemImage: "checkmark.circle")
                    }
                }
            }
            Spacer()
        }
        .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(KUNPalette.surface.opacity(0.86))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.white.opacity(0.80), lineWidth: 0.8)
            )
            .shadow(color: .black.opacity(0.035), radius: 18, x: 0, y: 10)
    }

    private func saveAPIKey() {
        do {
            try keychain.saveAPIKey(apiKey)
            apiKeyStatus = "已保存"
        } catch {
            apiKeyStatus = error.localizedDescription
        }
    }

    private func deleteAPIKey() {
        do {
            try keychain.deleteAPIKey()
            apiKey = ""
            apiKeyStatus = "已删除"
        } catch {
            apiKeyStatus = error.localizedDescription
        }
    }

    private func serviceIsOn(_ service: TranslationServiceKind) -> Bool {
        switch service {
        case .deepSeek:
            settingsStore.settings.openAIBaseURL == AppSettings.deepSeekBaseURL
        case .openAICompatible:
            settingsStore.settings.selectedEngine == .openAI
        case .system:
            settingsStore.settings.selectedEngine == .apple
        case .feishu:
            !feishuWebhookURL.trimmedForUI.isEmpty
        }
    }

    private func loadStoredSecrets() async {
        let store = keychain
        let values = await Task.detached(priority: .userInitiated) {
            (
                (try? store.readAPIKey()) ?? "",
                (try? store.readAPIKey(account: "feishuWebhook")) ?? ""
            )
        }.value
        apiKey = values.0
        feishuWebhookURL = values.1
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
        .background(KUNPalette.surface.opacity(0.74))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(KUNPalette.line.opacity(0.56))
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

    private func testFeishuConnection() async {
        let webhook = feishuWebhookURL.trimmedForUI
        guard !webhook.isEmpty else {
            feishuStatus = "请先填写 Webhook"
            return
        }

        isTestingFeishu = true
        feishuStatus = "正在发送..."
        defer { isTestingFeishu = false }

        do {
            try await FeishuWebhookClient().send(
                text: "困困翻译助手已成功连接飞书。",
                webhookURL: webhook
            )
            try keychain.saveAPIKey(webhook, account: "feishuWebhook")
            feishuStatus = "测试消息已发送"
        } catch {
            feishuStatus = error.localizedDescription
        }
    }

    private var availableEngines: [TranslationEngineKind] {
#if HAS_APPLE_TRANSLATION
        TranslationEngineKind.allCases.filter { $0 != .mock }
#else
        [.openAI]
#endif
    }

    private var settingsColumns: [GridItem] {
        [
            GridItem(.adaptive(minimum: 330, maximum: 520), spacing: 16, alignment: .top)
        ]
    }

    private func openHelp() {
        guard let url = URL(string: "https://github.com/duangjaiignacy-blip/kunkun") else { return }
        NSWorkspace.shared.open(url)
    }
}

private enum WorkspaceSection: CaseIterable, Identifiable {
    case translation
    case services
    case ocr
    case history
    case notes
    case general

    var id: Self { self }

    var title: String {
        switch self {
        case .translation: "翻译设置"
        case .services: "服务"
        case .ocr: "OCR 设置"
        case .history: "翻译记录"
        case .notes: "总结笔记"
        case .general: "通用设置"
        }
    }

    var systemImage: String {
        switch self {
        case .translation: "scope"
        case .services: "cube"
        case .ocr: "viewfinder"
        case .history: "text.book.closed"
        case .notes: "note.text"
        case .general: "gearshape"
        }
    }
}

private enum SidebarGroup: CaseIterable, Identifiable {
    case translation
    case ocr
    case general

    var id: Self { self }

    var title: String {
        switch self {
        case .translation: "翻译"
        case .ocr: "OCR"
        case .general: "通用"
        }
    }

    var sections: [WorkspaceSection] {
        switch self {
        case .translation: [.translation, .services, .history, .notes]
        case .ocr: [.ocr]
        case .general: [.general]
        }
    }
}

private enum ServiceMode: String, CaseIterable, Identifiable {
    case textTranslation
    case textRecognition
    case speechSynthesis

    var id: String { rawValue }

    var title: String {
        switch self {
        case .textTranslation: "文本翻译"
        case .textRecognition: "文本识别"
        case .speechSynthesis: "语音合成"
        }
    }
}

private enum TranslationServiceKind: CaseIterable, Identifiable {
    case deepSeek
    case openAICompatible
    case system
    case feishu

    var id: Self { self }

    var title: String {
        switch self {
        case .deepSeek: "DeepSeek 翻译"
        case .openAICompatible: "OpenAI 兼容"
        case .system: "系统翻译"
        case .feishu: "飞书通知"
        }
    }

    var subtitle: String {
        switch self {
        case .deepSeek: "默认推荐服务"
        case .openAICompatible: "自定义模型和接口"
        case .system: "Apple Translation"
        case .feishu: "群机器人 Webhook"
        }
    }

    var systemImage: String {
        switch self {
        case .deepSeek: "sparkles"
        case .openAICompatible: "server.rack"
        case .system: "macwindow"
        case .feishu: "paperplane"
        }
    }

    var isBuiltIn: Bool {
        switch self {
        case .deepSeek, .system: true
        case .openAICompatible, .feishu: false
        }
    }

    var tone: SoftServiceTone {
        switch self {
        case .deepSeek: .mint
        case .openAICompatible: .sky
        case .system: .peach
        case .feishu: .lemon
        }
    }
}

private enum SoftServiceTone {
    case mint
    case sky
    case peach
    case lemon

    var background: Color {
        switch self {
        case .mint: KUNPalette.mint.opacity(0.46)
        case .sky: KUNPalette.sky.opacity(0.42)
        case .peach: KUNPalette.peach.opacity(0.44)
        case .lemon: KUNPalette.lemon.opacity(0.52)
        }
    }

    var foreground: Color {
        switch self {
        case .mint: Color(red: 0.08, green: 0.39, blue: 0.34)
        case .sky: Color(red: 0.12, green: 0.30, blue: 0.45)
        case .peach: Color(red: 0.55, green: 0.26, blue: 0.13)
        case .lemon: Color(red: 0.42, green: 0.38, blue: 0.08)
        }
    }
}

private enum KUNPalette {
    static let canvas = Color(red: 0.965, green: 0.958, blue: 0.936)
    static let sidebar = Color(red: 0.925, green: 0.925, blue: 0.905)
    static let surface = Color(red: 1.0, green: 0.992, blue: 0.968)
    static let ink = Color(red: 0.045, green: 0.043, blue: 0.055)
    static let line = Color(red: 0.80, green: 0.79, blue: 0.74)
    static let mint = Color(red: 0.78, green: 0.90, blue: 0.88)
    static let sky = Color(red: 0.79, green: 0.89, blue: 0.92)
    static let peach = Color(red: 0.98, green: 0.86, blue: 0.76)
    static let lemon = Color(red: 0.94, green: 0.96, blue: 0.74)
}

private struct HomeHeroHeader: View {
    let historyCount: Int
    let noteCount: Int
    let engine: String
    let accessibilityOn: Bool
    let screenOn: Bool
    let onRefresh: () -> Void
    let onClear: () -> Void
    let onOpenOCR: () -> Void
    let onOpenSpeech: () -> Void
    let onOpenAI: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 22) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        StatusPill(title: engine, isOn: true)
                        StatusPill(title: accessibilityOn ? "辅助功能已生效" : "需要辅助功能", isOn: accessibilityOn)
                        StatusPill(title: screenOn ? "OCR 可用" : "OCR 需授权", isOn: screenOn)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Let's translate")
                            .font(.system(size: 34, weight: .semibold, design: .rounded))
                            .foregroundStyle(KUNPalette.ink)
                        Text("anything with ease")
                            .font(.system(size: 28, weight: .regular, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Text("划词、截图、朗读和 AI 总结都在这里开始。你的历史记录会自动沉淀成可复习的笔记。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 12)

                ZStack {
                    Image("AIAura")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 176, height: 176)
                        .opacity(0.92)
                    Circle()
                        .fill(.white.opacity(0.74))
                        .frame(width: 64, height: 64)
                    Image(systemName: "sparkles")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(KUNPalette.ink)
                }
                .frame(width: 190, height: 172)
            }

            HStack(spacing: 12) {
                HeroActionTile(title: "Camera", subtitle: "截图 OCR 翻译", systemImage: "camera.fill", tone: .sky, action: onOpenOCR)
                HeroActionTile(title: "Voice", subtitle: "朗读与发音", systemImage: "mic.fill", tone: .lemon, action: onOpenSpeech)
                HeroActionTile(title: "Translate AI", subtitle: "模型与增强", systemImage: "character.bubble.fill", tone: .peach, action: onOpenAI)
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 8) {
                    HStack(spacing: 10) {
                        SidebarMetric(title: "记录", value: "\(historyCount)", systemImage: "text.book.closed")
                            .frame(width: 86)
                        SidebarMetric(title: "笔记", value: "\(noteCount)", systemImage: "note.text")
                            .frame(width: 86)
                    }
                    HStack {
                        Button(action: onRefresh) {
                            Label("刷新", systemImage: "arrow.clockwise")
                        }
                        Button(role: .destructive, action: onClear) {
                            Label("清空", systemImage: "trash")
                        }
                    }
                    .buttonStyle(HeaderActionButtonStyle())
                }
            }
        }
        .padding(24)
        .background(
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(KUNPalette.surface)
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(
                        colors: [KUNPalette.lemon.opacity(0.48), .white.opacity(0.18), KUNPalette.sky.opacity(0.26)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.82), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 24, x: 0, y: 14)
        .padding(24)
        .padding(.bottom, -6)
        .background(KUNPalette.canvas)
    }
}

private struct HeroActionTile: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tone: SoftServiceTone
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white.opacity(0.86))
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(KUNPalette.ink)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(KUNPalette.ink)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                Image(systemName: "arrow.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tone.foreground)
                    .padding(8)
                    .background(Circle().fill(.white.opacity(0.62)))
            }
            .padding(12)
            .frame(width: 190, height: 72)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(tone.background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.white.opacity(0.76), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct AppBackdrop: View {
    var body: some View {
        ZStack(alignment: .topTrailing) {
            KUNPalette.canvas
            LinearGradient(
                colors: [
                    KUNPalette.lemon.opacity(0.34),
                    KUNPalette.sky.opacity(0.20),
                    KUNPalette.peach.opacity(0.16),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .center
            )
            .ignoresSafeArea()
            Image("AIAura")
                .resizable()
                .scaledToFit()
                .frame(width: 430, height: 430)
                .opacity(0.16)
                .blur(radius: 1.5)
                .padding(.top, 36)
                .padding(.trailing, 40)
        }
    }
}

private struct SidebarMetric: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(KUNPalette.ink)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline.weight(.semibold))
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.white.opacity(0.58))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.78), lineWidth: 0.8)
        )
    }
}

private struct PermissionMiniCard: View {
    let title: String
    let message: String
    let isGranted: Bool

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: isGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.callout.weight(.semibold))
                .foregroundStyle(isGranted ? .green : .orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill((isGranted ? KUNPalette.mint : KUNPalette.peach).opacity(0.45))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.68), lineWidth: 0.8)
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
                    .fill((isOn ? KUNPalette.mint : KUNPalette.peach).opacity(0.58))
            )
    }
}

private struct MetaChip: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(.white.opacity(0.62))
            )
            .overlay(
                Capsule()
                    .stroke(.white.opacity(0.76), lineWidth: 0.6)
            )
    }
}

private struct ServiceListRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let isBuiltIn: Bool
    let isOn: Bool
    let isSelected: Bool
    let tone: SoftServiceTone

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.white.opacity(isSelected ? 0.92 : 0.70))
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isSelected ? tone.foreground : .secondary)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isBuiltIn {
                Text("内置")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(tone.foreground)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.white.opacity(0.68)))
            }

            Toggle("", isOn: .constant(isOn))
                .labelsHidden()
                .controlSize(.small)
                .allowsHitTesting(false)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? tone.background : KUNPalette.surface.opacity(0.64))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? .white.opacity(0.86) : KUNPalette.line.opacity(0.38), lineWidth: 0.8)
        )
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
    }
}

private struct SettingsDetailSurface<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content

    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.title2.weight(.semibold))
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                content
            }
            .textFieldStyle(.roundedBorder)
            .controlSize(.large)
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(KUNPalette.surface.opacity(0.84))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.78), lineWidth: 0.8)
        )
        .shadow(color: .black.opacity(0.035), radius: 18, x: 0, y: 10)
    }
}

private struct TranslationServiceDetail: View {
    let selectedService: TranslationServiceKind
    @Bindable var settingsStore: SettingsStore
    @Binding var apiKey: String
    @Binding var apiKeyStatus: String
    @Binding var feishuWebhookURL: String
    @Binding var feishuStatus: String
    let isTestingFeishu: Bool
    let keychain: KeychainStore
    let saveAPIKey: () -> Void
    let deleteAPIKey: () -> Void
    let applyDeepSeek: (String) -> Void
    let testFeishuConnection: () -> Void

    var body: some View {
        switch selectedService {
        case .deepSeek:
            SettingsDetailSurface(title: "DeepSeek 翻译", subtitle: "推荐默认服务，兼容 OpenAI Chat Completions 请求格式。") {
                HStack {
                    Button("DeepSeek V4 Flash") {
                        applyDeepSeek("deepseek-v4-flash")
                    }
                    Button("DeepSeek V4 Pro") {
                        applyDeepSeek("deepseek-v4-pro")
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
                apiKeyFields
                Text("接口地址填 https://api.deepseek.com 即可，程序会自动补全 /chat/completions。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .openAICompatible:
            SettingsDetailSurface(title: "OpenAI 兼容服务", subtitle: "适合接入 OpenAI、硅基流动或其他兼容 Chat Completions 的服务。") {
                Button("切换为 OpenAI 默认") {
                    settingsStore.settings.selectedEngine = .openAI
                    settingsStore.settings.openAIModel = AppSettings.openAIModel
                    settingsStore.settings.openAIBaseURL = AppSettings.openAIBaseURL
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
                apiKeyFields
                Text("如果服务要求完整路径，可直接填写 /v1/chat/completions；否则程序会自动拼接。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .system:
            SettingsDetailSurface(title: "系统翻译", subtitle: "使用 Apple Translation。macOS 15+ 可启用，当前构建会自动隐藏不可用能力。") {
#if HAS_APPLE_TRANSLATION
                Button("切换为 Apple 翻译") {
                    settingsStore.settings.selectedEngine = .apple
                }
                Text("可用：系统会按需下载翻译模型。")
                    .foregroundStyle(.secondary)
#else
                Label("当前 macOS 14 构建不可用", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("升级到 macOS 15+ 并使用支持 Translation Framework 的 Xcode 构建后可启用。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
#endif
            }
        case .feishu:
            SettingsDetailSurface(title: "飞书通知", subtitle: "把测试消息或后续自动化摘要发送到飞书群机器人。") {
                SecureField("飞书群机器人 Webhook", text: $feishuWebhookURL)
                HStack {
                    Button("保存 Webhook") {
                        do {
                            try keychain.saveAPIKey(feishuWebhookURL.trimmedForUI, account: "feishuWebhook")
                            feishuStatus = "已保存"
                        } catch {
                            feishuStatus = error.localizedDescription
                        }
                    }
                    Button("删除 Webhook") {
                        do {
                            try keychain.deleteAPIKey(account: "feishuWebhook")
                            feishuWebhookURL = ""
                            feishuStatus = "已删除"
                        } catch {
                            feishuStatus = error.localizedDescription
                        }
                    }
                    Button(isTestingFeishu ? "发送中..." : "发送测试消息") {
                        testFeishuConnection()
                    }
                    .disabled(isTestingFeishu || feishuWebhookURL.trimmedForUI.isEmpty)
                    Text(feishuStatus)
                        .foregroundStyle(.secondary)
                }
                Text("Webhook 会保存在 macOS Keychain，不写入 UserDefaults。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var apiKeyFields: some View {
        VStack(alignment: .leading, spacing: 10) {
            SecureField("API Key", text: $apiKey)
            HStack {
                Button("保存 API Key", action: saveAPIKey)
                Button("删除 API Key", action: deleteAPIKey)
                Text(apiKeyStatus)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct StatusLine: View {
    let title: String
    let isOn: Bool

    var body: some View {
        HStack {
            Label(title, systemImage: isOn ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(isOn ? .green : .orange)
            Spacer()
            Text(isOn ? "已生效" : "未生效")
                .foregroundStyle(.secondary)
        }
    }
}

private extension View {
    func serviceListBackground() -> some View {
        self
            .frame(minHeight: 420, alignment: .top)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(KUNPalette.surface.opacity(0.62))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.white.opacity(0.76), lineWidth: 0.8)
            )
            .shadow(color: .black.opacity(0.03), radius: 16, x: 0, y: 10)
    }
}

private struct SidebarButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(isSelected ? .semibold : .regular))
            .foregroundStyle(isSelected ? KUNPalette.ink : Color.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? KUNPalette.lemon.opacity(0.68) : Color.clear)
            )
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(isSelected ? KUNPalette.ink : Color.clear)
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
                    .fill(configuration.isPressed ? KUNPalette.lemon.opacity(0.62) : .white.opacity(0.72))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.white.opacity(0.82), lineWidth: 0.8)
            )
    }
}

private struct HistoryRow: View {
    let item: HistoryItem

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(KUNPalette.sky.opacity(0.94))
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
                .fill(KUNPalette.surface.opacity(0.74))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.76), lineWidth: 0.8)
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
                .fill(KUNPalette.surface.opacity(0.74))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.76), lineWidth: 0.8)
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
                .fill((secondary ? KUNPalette.mint : KUNPalette.surface).opacity(secondary ? 0.36 : 0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.78), lineWidth: 0.8)
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
        .background(KUNPalette.surface.opacity(0.32))
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
                .fill(.white.opacity(0.78))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.82), lineWidth: 0.8)
        )
    }
}

private struct SettingsPanel<Content: View>: View {
    let title: String
    let systemImage: String
    let content: Content

    init(title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .textFieldStyle(.roundedBorder)
            .controlSize(.regular)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(KUNPalette.surface.opacity(0.78))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.78), lineWidth: 0.8)
        )
        .frame(maxWidth: .infinity, alignment: .topLeading)
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

private struct FeishuWebhookClient {
    func send(text: String, webhookURL: String) async throws {
        guard let url = URL(string: webhookURL),
              let scheme = url.scheme,
              ["https", "http"].contains(scheme.lowercased()) else {
            throw KUNError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            FeishuTextMessage(
                msgType: "text",
                content: .init(text: text)
            )
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw KUNError.invalidResponse
        }

        if let result = try? JSONDecoder().decode(FeishuWebhookResponse.self, from: data),
           let code = result.code,
           code != 0 {
            throw KUNError.translationUnavailable(result.message ?? "飞书 Webhook 返回错误。")
        }
    }
}

private struct FeishuTextMessage: Encodable {
    let msgType: String
    let content: Content

    enum CodingKeys: String, CodingKey {
        case msgType = "msg_type"
        case content
    }

    struct Content: Encodable {
        let text: String
    }
}

private struct FeishuWebhookResponse: Decodable {
    let code: Int?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case code
        case message
        case msg
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decodeIfPresent(Int.self, forKey: .code)
        message = try container.decodeIfPresent(String.self, forKey: .message)
            ?? container.decodeIfPresent(String.self, forKey: .msg)
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
