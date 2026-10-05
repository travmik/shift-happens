import Carbon.HIToolbox
import Foundation

/// A global-hotkey combination: a Carbon virtual key code plus Carbon modifier
/// masks (cmdKey, optionKey, controlKey, shiftKey).
public struct HotkeyConfig: Codable, Equatable {
    public var keyCode: UInt32
    public var modifiers: UInt32

    public init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// ⌥⌘K — the original default.
    public static let standard = HotkeyConfig(
        keyCode: UInt32(kVK_ANSI_K),
        modifiers: UInt32(optionKey | cmdKey)
    )

    /// Human-readable symbol for the key code, for key-cap display.
    public var keySymbol: String {
        if let named = Self.keyNames[Int(keyCode)] {
            return named
        }
        return "Key \(keyCode)"
    }

    /// Modifier glyphs in canonical order: ⌃ ⌥ ⇧ ⌘.
    public var modifierSymbols: [String] {
        var symbols: [String] = []
        if modifiers & UInt32(controlKey) != 0 { symbols.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { symbols.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0 { symbols.append("⇧") }
        if modifiers & UInt32(cmdKey) != 0 { symbols.append("⌘") }
        return symbols
    }

    private static let keyNames: [Int: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2",
        20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8",
        29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "Return",
        37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N",
        46: "M", 47: ".", 49: "Space", 50: "`", 51: "Delete", 53: "Esc", 96: "F5",
        97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9", 103: "F11", 105: "F13",
        107: "F14", 109: "F10", 111: "F12", 113: "F15", 118: "F4", 119: "F2", 120: "F1",
        123: "←", 124: "→", 125: "↓", 126: "↑"
    ]
}
