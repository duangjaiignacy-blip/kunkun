import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var container: DependencyContainer!
    private var statusItem: NSStatusItem?

    func applicationWillFinishLaunching(_ notification: Notification) {
        #if !APP_STORE
        redirectDiskImageLaunchIfNeeded()
        #endif
        terminateDuplicateInstances()
        NSApp.setActivationPolicy(.regular)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        container = DependencyContainer()
        setupStatusItem()
        container.start()
        container.settingsWindowController.show()
    }

    func applicationWillTerminate(_ notification: Notification) {
        container.speechService.stop()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        container?.settingsWindowController.show()
        return true
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "globe.asia.australia.fill", accessibilityDescription: "困困翻译助手")
        item.button?.title = " 困困"
        item.button?.toolTip = "困困翻译助手：点击打开菜单"
        item.menu = makeMenu()
        statusItem = item
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(
            NSMenuItem(
                title: "翻译选中文本",
                action: #selector(translateSelection),
                keyEquivalent: ""
            )
        )
        menu.addItem(
            NSMenuItem(
                title: "截图 OCR 翻译",
                action: #selector(translateScreenshot),
                keyEquivalent: ""
            )
        )
        menu.addItem(
            NSMenuItem(
                title: "朗读选中文本",
                action: #selector(speakSelection),
                keyEquivalent: ""
            )
        )
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "打开主界面", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "完全退出困困翻译助手", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        return menu
    }

    #if !APP_STORE
    private func redirectDiskImageLaunchIfNeeded() {
        let currentPath = Bundle.main.bundleURL.path
        guard currentPath.hasPrefix("/Volumes/") else { return }

        let installedURL = URL(fileURLWithPath: "/Applications/KUNTranslator.app")
        if FileManager.default.fileExists(atPath: installedURL.path) {
            NSWorkspace.shared.openApplication(
                at: installedURL,
                configuration: NSWorkspace.OpenConfiguration()
            )
            NSApp.terminate(nil)
        }
    }
    #endif

    private func terminateDuplicateInstances() {
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let currentPath = Bundle.main.bundleURL.path
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "com.kun.translator")

        for app in running where app.processIdentifier != currentPID {
            let otherPath = app.bundleURL?.path ?? ""
            if currentPath == "/Applications/KUNTranslator.app" || otherPath.hasPrefix("/Volumes/") {
                app.terminate()
            }
        }
    }

    @objc private func translateSelection() {
        container.commandRouter.translateSelection()
    }

    @objc private func translateScreenshot() {
        container.commandRouter.translateScreenshot()
    }

    @objc private func speakSelection() {
        container.commandRouter.speakSelection()
    }

    @objc private func openSettings() {
        container.settingsWindowController.show()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
