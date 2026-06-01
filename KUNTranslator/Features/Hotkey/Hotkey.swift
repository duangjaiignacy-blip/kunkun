import Foundation
import Carbon

struct Hotkey: Codable, Hashable, Identifiable, Sendable {
    var id: String { "\(keyCode)-\(modifiers.carbonFlags)" }
    var keyCode: UInt32
    var modifiers: HotkeyModifiers

    var displayString: String {
        "\(modifiers.displayString)\(Self.keyName(for: keyCode))"
    }

    static func keyName(for keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_ANSI_A: "A"
        case kVK_ANSI_B: "B"
        case kVK_ANSI_C: "C"
        case kVK_ANSI_D: "D"
        case kVK_ANSI_E: "E"
        case kVK_ANSI_F: "F"
        case kVK_ANSI_G: "G"
        case kVK_ANSI_H: "H"
        case kVK_ANSI_I: "I"
        case kVK_ANSI_J: "J"
        case kVK_ANSI_K: "K"
        case kVK_ANSI_L: "L"
        case kVK_ANSI_M: "M"
        case kVK_ANSI_N: "N"
        case kVK_ANSI_O: "O"
        case kVK_ANSI_P: "P"
        case kVK_ANSI_Q: "Q"
        case kVK_ANSI_R: "R"
        case kVK_ANSI_S: "S"
        case kVK_ANSI_T: "T"
        case kVK_ANSI_U: "U"
        case kVK_ANSI_V: "V"
        case kVK_ANSI_W: "W"
        case kVK_ANSI_X: "X"
        case kVK_ANSI_Y: "Y"
        case kVK_ANSI_Z: "Z"
        default: "按键 \(keyCode)"
        }
    }
}

struct HotkeyModifiers: OptionSet, Codable, Hashable, Sendable {
    let rawValue: UInt32

    static let command = HotkeyModifiers(rawValue: 1 << 0)
    static let shift = HotkeyModifiers(rawValue: 1 << 1)
    static let option = HotkeyModifiers(rawValue: 1 << 2)
    static let control = HotkeyModifiers(rawValue: 1 << 3)

    var carbonFlags: UInt32 {
        var flags: UInt32 = 0
        if contains(.command) { flags |= UInt32(cmdKey) }
        if contains(.shift) { flags |= UInt32(shiftKey) }
        if contains(.option) { flags |= UInt32(optionKey) }
        if contains(.control) { flags |= UInt32(controlKey) }
        return flags
    }

    var displayString: String {
        var parts: [String] = []
        if contains(.control) { parts.append("⌃") }
        if contains(.option) { parts.append("⌥") }
        if contains(.shift) { parts.append("⇧") }
        if contains(.command) { parts.append("⌘") }
        return parts.joined()
    }
}

enum HotkeyAction: UInt32, CaseIterable, Sendable {
    case translateSelection = 1
    case translateScreenshot = 2
    case speakSelection = 3
}
