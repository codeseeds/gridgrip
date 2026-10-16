import Foundation

/// 키보드 단축키 수정자 집합. Fn·CapsLock은 쓰지 않는다(Carbon 전역 단축키가 받지 않음).
/// 마우스용 `MouseModifierSet`과는 별개 타입이다.
public struct ModifierSet: OptionSet, Hashable, Codable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let control = ModifierSet(rawValue: 1 << 0)
    public static let option = ModifierSet(rawValue: 1 << 1)
    public static let shift = ModifierSet(rawValue: 1 << 2)
    public static let command = ModifierSet(rawValue: 1 << 3)

    /// 표시·저장 순서. Apple 메뉴 표기 순서(⌃⌥⇧⌘)와 같다.
    static let ordered: [(flag: ModifierSet, name: String, symbol: String, carbon: UInt32)] = [
        (.control, "control", "⌃", 0x1000),
        (.option, "option", "⌥", 0x0800),
        (.shift, "shift", "⇧", 0x0200),
        (.command, "command", "⌘", 0x0100),
    ]

    /// 저장용 이름 배열(⌃⌥⇧⌘ 순서).
    public var names: [String] {
        Self.ordered.filter { contains($0.flag) }.map(\.name)
    }

    /// 이름 배열에서 만든다. 모르는 이름이 하나라도 있으면 nil.
    public init?(names: [String]) {
        var set: ModifierSet = []
        for name in names {
            guard let entry = Self.ordered.first(where: { $0.name == name }) else { return nil }
            set.insert(entry.flag)
        }
        self = set
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let names = try container.decode([String].self)
        guard let set = ModifierSet(names: names) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "알 수 없는 수정자: \(names)")
        }
        self = set
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(names)
    }
}

/// 전역 단축키 조합 1개 = 가상 키코드 + 수정자.
public struct KeyCombo: Hashable, Codable {
    public let keyCode: UInt32
    public let modifiers: ModifierSet

    public init(keyCode: UInt32, modifiers: ModifierSet) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// 예: `⌥⇧⌘H`. 수정자는 입력 순서와 무관하게 ⌃⌥⇧⌘ 순서.
    public var displayString: String {
        let symbols = ModifierSet.ordered.filter { modifiers.contains($0.flag) }.map(\.symbol).joined()
        return symbols + KeyCodeNames.name(for: keyCode)
    }

    /// Carbon `controlKey/optionKey/shiftKey/cmdKey`와 같은 숫자의 합. WindowCore는 Carbon을 import하지 않는다.
    public var carbonModifierFlags: UInt32 {
        ModifierSet.ordered.filter { modifiers.contains($0.flag) }.reduce(0) { $0 | $1.carbon }
    }
}
