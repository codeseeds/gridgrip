import Foundation

/// 녹화 칸이 받은 NSEvent 수정자를 실행 타깃이 이 형식으로 바꿔 넘긴다(WindowCore는 AppKit 금지).
public struct RecordingModifiers: OptionSet, Hashable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let control = RecordingModifiers(rawValue: 1 << 0)
    public static let option = RecordingModifiers(rawValue: 1 << 1)
    public static let shift = RecordingModifiers(rawValue: 1 << 2)
    public static let command = RecordingModifiers(rawValue: 1 << 3)
    public static let function = RecordingModifiers(rawValue: 1 << 4)
    public static let capsLock = RecordingModifiers(rawValue: 1 << 5)
}

public enum RecordingIntent: Equatable {
    /// 엔진에 넘길 조합. 겹침·시스템 필수 조합 판정은 `ShortcutEngine.setShortcut` 결과로 받는다.
    case commit(KeyCombo)
    case cancel
    case clear
    /// ⌃·⌥·⌘ 중 하나도 없음(0개 또는 Shift만). 녹화를 계속한다.
    case rejectNoModifier
    /// 수정자 키 자체 입력. 녹화를 계속한다.
    case ignore
}

/// 녹화 입력 판정. 수정자 규칙의 정본은 `ShortcutValidator`이고, 이 함수는 그 결과를 녹화 의도로 바꾼다.
public enum ShortcutRecordingInterpreter {
    private static let modifierKeyCodes: Set<UInt16> = [0x37, 0x36, 0x38, 0x3C, 0x3A, 0x3D, 0x3B, 0x3E, 0x3F, 0x39]
    private static let escapeKeyCode: UInt16 = 0x35
    private static let deleteKeyCodes: Set<UInt16> = [0x33, 0x75]

    public static func interpret(keyCode: UInt16, modifiers: RecordingModifiers) -> RecordingIntent {
        if modifierKeyCodes.contains(keyCode) { return .ignore }

        // Fn·CapsLock은 키보드 단축키 수정자로 쓰지 않는다(방향키·F키에 시스템이 붙이는 Fn 비트 포함).
        let keyModifiers = modifierSet(modifiers)
        if keyModifiers.isEmpty {
            if keyCode == escapeKeyCode { return .cancel }
            if deleteKeyCodes.contains(keyCode) { return .clear }
        }

        let combo = KeyCombo(keyCode: UInt32(keyCode), modifiers: keyModifiers)
        // 시스템 필수 조합은 수정자 규칙은 만족하므로 엔진에 넘겨 `.invalidModifiers`로 거부받는다.
        if ShortcutValidator.validate(combo) || ShortcutValidator.isReserved(combo) {
            return .commit(combo)
        }
        return .rejectNoModifier
    }

    private static func modifierSet(_ modifiers: RecordingModifiers) -> ModifierSet {
        var set: ModifierSet = []
        if modifiers.contains(.control) { set.insert(.control) }
        if modifiers.contains(.option) { set.insert(.option) }
        if modifiers.contains(.shift) { set.insert(.shift) }
        if modifiers.contains(.command) { set.insert(.command) }
        return set
    }
}
