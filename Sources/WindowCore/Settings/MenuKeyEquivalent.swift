import Foundation

/// KeyCombo → `MenuItemSpec.keyEquivalent`/`modifiers` 값.
/// 문자 키는 소문자, 방향키·F키는 NSFunctionKey 유니코드 값(AppKit 없이 숫자 상수로).
public enum MenuKeyEquivalent {
    private static let specialKeys: [UInt32: String] = [
        0x7B: scalar(0xF702), 0x7C: scalar(0xF703), 0x7D: scalar(0xF701), 0x7E: scalar(0xF700),  // ← → ↓ ↑
        0x7A: scalar(0xF704), 0x78: scalar(0xF705), 0x63: scalar(0xF706), 0x76: scalar(0xF707),  // F1~F4
        0x60: scalar(0xF708), 0x61: scalar(0xF709), 0x62: scalar(0xF70A), 0x64: scalar(0xF70B),  // F5~F8
        0x65: scalar(0xF70C), 0x6D: scalar(0xF70D), 0x67: scalar(0xF70E), 0x6F: scalar(0xF70F),  // F9~F12
        0x31: " ", 0x24: "\r", 0x30: "\t", 0x33: "\u{08}", 0x35: "\u{1B}",
    ]

    /// 표시할 수 없는 키코드면 nil.
    public static func keyEquivalent(for keyCode: UInt32) -> String? {
        if let special = specialKeys[keyCode] { return special }
        let name = KeyCodeNames.name(for: keyCode)
        guard name.count == 1 else { return nil }
        return name.lowercased()
    }

    public static func menuModifiers(_ modifiers: ModifierSet) -> MenuModifiers {
        var result: MenuModifiers = []
        if modifiers.contains(.control) { result.insert(.control) }
        if modifiers.contains(.option) { result.insert(.option) }
        if modifiers.contains(.shift) { result.insert(.shift) }
        if modifiers.contains(.command) { result.insert(.command) }
        return result
    }

    private static func scalar(_ value: UInt32) -> String {
        String(Character(UnicodeScalar(value)!))
    }
}
