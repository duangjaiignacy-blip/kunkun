import XCTest

final class HotkeySettingsTests: XCTestCase {
    func testDefaultHotkeysDoNotConflict() {
        XCTAssertFalse(GlobalHotkeyManager.hasConflicts(.default))
    }

    func testDefaultHotkeysAvoidCommonBrowserShortcuts() {
        XCTAssertEqual(HotkeySettings.default.translateSelection.displayString, "⌃⌥T")
        XCTAssertEqual(HotkeySettings.default.translateScreenshot.displayString, "⌃⌥Q")
        XCTAssertEqual(HotkeySettings.default.speakSelection.displayString, "⌃⌥S")
    }

    func testConflictDetection() {
        let hotkey = HotkeySettings.default.translateSelection
        let settings = HotkeySettings(
            translateSelection: hotkey,
            translateScreenshot: hotkey,
            speakSelection: HotkeySettings.default.speakSelection
        )
        XCTAssertTrue(GlobalHotkeyManager.hasConflicts(settings))
    }

    func testSettingsRoundTrip() throws {
        let data = try JSONEncoder().encode(AppSettings.default)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertEqual(decoded, .default)
    }

    func testAppearanceMapsToWindowStyle() {
        XCTAssertNil(AppAppearance.system.windowStyleName)
        XCTAssertEqual(AppAppearance.light.windowStyleName, "light")
        XCTAssertEqual(AppAppearance.dark.windowStyleName, "dark")
    }
}
