import Foundation

/// 마우스 조작용 수정자 조합. 저장값은 이 자체 비트(CGEventFlags 원값을 저장하지 않음).
/// 키보드 단축키용 `ModifierSet`과 별개 타입이다.
public struct MouseModifierSet: OptionSet, Hashable, Codable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let shift = MouseModifierSet(rawValue: 1)
    public static let fn = MouseModifierSet(rawValue: 2)
    public static let control = MouseModifierSet(rawValue: 4)
    public static let option = MouseModifierSet(rawValue: 8)
    public static let command = MouseModifierSet(rawValue: 16)

    /// 알려진 5개 비트 전부(31). 이 밖의 비트는 손상값으로 본다.
    public static let all: MouseModifierSet = [.shift, .fn, .control, .option, .command]

    /// CGEventFlags의 CapsLock 비트(alphaShift).
    public static let capsLockFlag: UInt64 = 0x10000

    private static let flagMasks: [(MouseModifierSet, UInt64)] = [
        (.shift, 0x20000),
        (.fn, 0x800000),
        (.control, 0x40000),
        (.option, 0x80000),
        (.command, 0x100000),
    ]

    /// 이 조합에 해당하는 CGEventFlags 비트.
    public var cgEventFlagsMask: UInt64 {
        Self.flagMasks.reduce(0) { mask, pair in contains(pair.0) ? mask | pair.1 : mask }
    }

    /// CGEventFlags 원값에서 5개 수정자만 뽑는다. CapsLock·비결합·숫자패드 등 다른 비트는 무시한다.
    public init(cgEventFlags flags: UInt64) {
        self = Self.flagMasks.reduce(into: []) { set, pair in
            if flags & pair.1 != 0 { set.insert(pair.0) }
        }
    }
}

/// 수정자 판정 결과(조작 종류).
public enum MouseAction: Equatable {
    case move
    case resize

    /// 창 변경 기록의 출처.
    public var changeSource: WindowChangeSource {
        switch self {
        case .move: return .mouseMove
        case .resize: return .mouseResize
        }
    }
}

/// 이벤트 탭 마스크 정본: mouseMoved(1<<5) | flagsChanged(1<<12). 실행 타깃은 이 값만 쓴다.
public enum MouseDragEventMask {
    public static let value: UInt64 = (1 << 5) | (1 << 12)
}
