import AppKit

struct CapturedShortcut {
    let key: String
    let modifiers: [String]
}

enum ShortcutCapture {
    static func parse(event: NSEvent) -> CapturedShortcut? {
        guard let key = karabinerKey(for: event) else {
            return nil
        }

        var modifiers: [String] = []
        let flags = event.modifierFlags
        if flags.contains(.command) {
            modifiers.append("command")
        }
        if flags.contains(.control) {
            modifiers.append("control")
        }
        if flags.contains(.option) {
            modifiers.append("option")
        }
        if flags.contains(.shift) {
            modifiers.append("shift")
        }
        if flags.contains(.function) {
            modifiers.append("fn")
        }

        return CapturedShortcut(key: key, modifiers: modifiers)
    }

    private static func karabinerKey(for event: NSEvent) -> String? {
        switch event.keyCode {
        case 0: return "a"
        case 1: return "s"
        case 2: return "d"
        case 3: return "f"
        case 4: return "h"
        case 5: return "g"
        case 6: return "z"
        case 7: return "x"
        case 8: return "c"
        case 9: return "v"
        case 11: return "b"
        case 12: return "q"
        case 13: return "w"
        case 14: return "e"
        case 15: return "r"
        case 16: return "y"
        case 17: return "t"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 24: return "equal_sign"
        case 25: return "9"
        case 26: return "7"
        case 27: return "hyphen"
        case 28: return "8"
        case 29: return "0"
        case 30: return "close_bracket"
        case 31: return "o"
        case 32: return "u"
        case 33: return "open_bracket"
        case 34: return "i"
        case 35: return "p"
        case 36: return "return_or_enter"
        case 37: return "l"
        case 38: return "j"
        case 39: return "quote"
        case 40: return "k"
        case 41: return "semicolon"
        case 42: return "backslash"
        case 43: return "comma"
        case 44: return "slash"
        case 45: return "n"
        case 46: return "m"
        case 47: return "period"
        case 48: return "tab"
        case 49: return "spacebar"
        case 50: return "grave_accent_and_tilde"
        case 51: return "delete_or_backspace"
        case 53: return "escape"
        case 57: return "caps_lock"
        case 123: return "left_arrow"
        case 124: return "right_arrow"
        case 125: return "down_arrow"
        case 126: return "up_arrow"
        default:
            return nil
        }
    }
}
