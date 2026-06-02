# KUN Translator 困困翻译助手

KUN Translator 是一款 macOS 原生菜单栏翻译助手，使用 SwiftUI、AppKit、Accessibility、Vision OCR、ScreenCaptureKit、AVSpeechSynthesizer、SQLite 和 OpenAI-compatible AI 增强客户端构建。

## 环境要求

- macOS 14.4+
- Xcode 16+
- XcodeGen，或仓库内的 `.tools/bin/xcodegen`
- `create-dmg` 可选；没有安装时脚本会自动使用 `hdiutil` 兜底

如果 `xcodebuild` 提示当前 `xcode-select` 指向 Command Line Tools，请先切到完整 Xcode：

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

## 构建与测试

```bash
.tools/bin/xcodegen generate
xcodebuild build-for-testing -scheme KUNTranslator -destination 'platform=macOS,arch=arm64' -derivedDataPath build/DerivedData
/Users/mac/Downloads/Xcode.app/Contents/Developer/usr/bin/xctest build/DerivedData/Build/Products/Debug/KUNTranslatorTests.xctest
```

当前本机 Xcode 16.1 的 `xcodebuild test/test-without-building` 对这个独立 macOS XCTest bundle 会误报找不到 bundle 可执行文件；测试产物本身可由 `xctest` 直接执行。

## 打包

```bash
xcodebuild -scheme KUNTranslator -configuration Release -destination 'platform=macOS,arch=arm64' -derivedDataPath build/DerivedData build
Scripts/package-dmg.sh path/to/KUNTranslator.app KUNTranslator.dmg
```

## Mac App Store 构建

仓库保留两个发布形态：

- `KUNTranslator`：直装 / DMG 版，使用本地签名和非沙盒 entitlements。
- `KUNTranslator-AppStore`：Mac App Store 版，使用 `AppStore` 配置、App Sandbox、Privacy Manifest 和 App Store 审核资料模板。

App Store 版必须使用 Apple Developer Program 账号在 Xcode 中签名。配置好 Team 后运行：

```bash
.tools/bin/xcodegen generate
DEVELOPMENT_TEAM=你的TeamID ALLOW_PROVISIONING_UPDATES=1 Scripts/archive-appstore.sh
```

生成的 archive 位于：

```bash
build/AppStore/KUNTranslator.xcarchive
```

然后用 Xcode Organizer 上传到 App Store Connect，或继续使用命令行导出/上传：

```bash
Scripts/export-appstore.sh
Scripts/upload-appstore.sh
```

如果使用 App Store Connect API Key：

```bash
export ASC_KEY_PATH="$HOME/.appstoreconnect/private_keys/AuthKey_XXXXXXXXXX.p8"
export ASC_KEY_ID="XXXXXXXXXX"
export ASC_ISSUER_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
DEVELOPMENT_TEAM=你的TeamID ALLOW_PROVISIONING_UPDATES=1 Scripts/archive-appstore.sh
Scripts/upload-appstore.sh
```

相关文件：

- `KUNTranslator/KUNTranslator-AppStore.entitlements`
- `KUNTranslator/Resources/PrivacyInfo.xcprivacy`
- `AppStore/ExportOptions.plist`
- `AppStore/ExportOptions-Upload.plist`
- `AppStore/Metadata.md`
- `AppStore/PrivacyPolicy.md`
- `AppStore/ReviewNotes.md`

## 默认快捷键

- 翻译选中文本：`Control + Option + T`
- 截图 OCR 翻译：`Control + Option + Q`
- 朗读选中文本：`Control + Option + S`

## DeepSeek 配置

默认翻译服务已切到 DeepSeek：

- 模型：`deepseek-v4-flash`
- 接口地址：`https://api.deepseek.com`
- 请求端点：程序会自动补成 `/chat/completions`
- AI 增强：默认开启

打开设置页的“AI”标签，粘贴你的 DeepSeek API Key 后点击“保存 API Key”。如果想切换模型，可点“使用 DeepSeek V4 Flash”或“使用 DeepSeek V4 Pro”。

## 权限

KUN Translator 需要：

- 辅助功能：读取其他 App 中的选中文字、执行剪贴板兜底读取。
- 屏幕录制：截图 OCR 翻译。

如果系统设置里看起来已经开启，但 App 内仍显示未授权，请按这个顺序处理：

1. 退出 KUNTranslator。
2. 打开系统设置的“隐私与安全性 > 辅助功能”和“屏幕与系统录音”。
3. 删除旧的 KUNTranslator 条目。
4. 重新添加 `/Applications/KUNTranslator.app`。
5. 打开开关后重新启动 KUNTranslator。

当前安装版使用稳定本地签名 `KUN Translator Local Signing`，重新添加一次后，后续覆盖安装不会再因为临时签名变化反复失效。

诊断日志位置：

```bash
tail -f "$HOME/Library/Application Support/KUNTranslator/diagnostic.log"
```
