import Foundation

public enum MouseDragSettingsError: Error, Equatable {
    case emptyMoveModifiers
    case emptyResizeModifiers
    case identicalModifiers
}

/// 마우스 조작 설정. 설정 화면도 이 타입을 그대로 쓴다.
public struct MouseDragSettings: Codable, Equatable {
    public var moveModifiers: MouseModifierSet
    public var resizeModifiers: MouseModifierSet
    public var bringWindowToFront: Bool

    public init(moveModifiers: MouseModifierSet, resizeModifiers: MouseModifierSet, bringWindowToFront: Bool) {
        self.moveModifiers = moveModifiers
        self.resizeModifiers = resizeModifiers
        self.bringWindowToFront = bringWindowToFront
    }

    /// 이동 Fn+Ctrl, 크기조정 Fn+Opt, 앞으로 가져오기 ON.
    public static let `default` = MouseDragSettings(
        moveModifiers: [.fn, .control],
        resizeModifiers: [.fn, .option],
        bringWindowToFront: true
    )

    /// 수정자 0개 금지, 이동 = 크기조정 같은 조합 금지. 빈 배열이면 유효.
    public func validate() -> [MouseDragSettingsError] {
        var errors: [MouseDragSettingsError] = []
        if moveModifiers.isEmpty { errors.append(.emptyMoveModifiers) }
        if resizeModifiers.isEmpty { errors.append(.emptyResizeModifiers) }
        if !moveModifiers.isEmpty && moveModifiers == resizeModifiers { errors.append(.identicalModifiers) }
        return errors
    }
}

/// `mouse.*` 키 3종 저장/로드. 매번 생성해 쓰는 값 타입.
public struct MouseDragSettingsStore {
    public static let moveModifiersKey = "mouse.moveModifiers"
    public static let resizeModifiersKey = "mouse.resizeModifiers"
    public static let bringWindowToFrontKey = "mouse.bringWindowToFront"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    /// 복구 규칙: 필드별 기본값 대체 → 다시 검증 → 그래도 무효면 전체 기본값. 저장소에는 쓰지 않는다.
    public func load() -> MouseDragSettings {
        let fallback = MouseDragSettings.default
        let repaired = MouseDragSettings(
            moveModifiers: modifiers(forKey: Self.moveModifiersKey) ?? fallback.moveModifiers,
            resizeModifiers: modifiers(forKey: Self.resizeModifiersKey) ?? fallback.resizeModifiers,
            bringWindowToFront: bool(forKey: Self.bringWindowToFrontKey) ?? fallback.bringWindowToFront
        )
        return repaired.validate().isEmpty ? repaired : fallback
    }

    /// 검증에 실패하면 첫 오류를 throw하고 아무것도 쓰지 않는다.
    public func save(_ settings: MouseDragSettings) throws {
        if let error = settings.validate().first { throw error }
        defaults.set(settings.moveModifiers.rawValue, forKey: Self.moveModifiersKey)
        defaults.set(settings.resizeModifiers.rawValue, forKey: Self.resizeModifiersKey)
        defaults.set(settings.bringWindowToFront, forKey: Self.bringWindowToFrontKey)
    }

    /// 정수(Bool 아님)이고 0이 아니며 알려진 5비트 안일 때만 값으로 인정한다.
    private func modifiers(forKey key: String) -> MouseModifierSet? {
        guard let number = defaults.object(forKey: key) as? NSNumber, !Self.isBoolean(number) else { return nil }
        guard let raw = Int(exactly: number.doubleValue) else { return nil }
        let set = MouseModifierSet(rawValue: raw)
        guard !set.isEmpty, MouseModifierSet.all.isSuperset(of: set) else { return nil }
        return set
    }

    /// Bool로 저장된 값만 인정한다(문자열 "yes" 같은 값은 손상값).
    private func bool(forKey key: String) -> Bool? {
        guard let number = defaults.object(forKey: key) as? NSNumber, Self.isBoolean(number) else { return nil }
        return number.boolValue
    }

    private static func isBoolean(_ number: NSNumber) -> Bool {
        CFGetTypeID(number) == CFBooleanGetTypeID()
    }
}
