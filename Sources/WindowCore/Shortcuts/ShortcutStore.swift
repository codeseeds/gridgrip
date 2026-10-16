import Foundation

/// 로드 중 저장값을 고친 사실. 로그는 실행 타깃이 찍는다(WindowCore는 `os` import 금지).
public enum ShortcutLoadIssue: Equatable {
    /// JSON 손상·디코딩 실패·`version` ≠ 1 → 전체 기본값.
    case corruptData
    /// `ShortcutValidator.validate` 불통과(수정자 규칙·키코드 범위·시스템 필수 조합)·모르는 수정자 이름·형식이 깨진 항목 → 그 동작만 기본값.
    case invalidModifiers(WindowAction)
    /// 정리 결과 앞선 동작과 겹침 → 이 동작을 nil로.
    case duplicateCleared(WindowAction)
}

/// UserDefaults 키 `shortcuts.v1`에 단축키를 저장·로드한다. 이 키 외에는 읽고 쓰지 않는다.
/// 형식: `{"version":1,"bindings":{"left":{"keyCode":4,"modifiers":["option","shift","command"]},"undo":null}}`
public final class ShortcutStore {
    public static let key = "shortcuts.v1"
    private static let version = 1

    public private(set) var lastLoadIssues: [ShortcutLoadIssue] = []
    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    /// 저장값 없음 → 기본값. 없는 동작 → 그 동작만 기본값. `null` → 지운 상태. 모르는 키 → 무시.
    /// 손상되면 크래시하지 않고 기본값으로 복구하며 `lastLoadIssues`에 사유를 남긴다. 저장값을 고쳐 쓰지는 않는다.
    public func load() -> ShortcutBindings {
        lastLoadIssues = []
        guard let object = defaults.object(forKey: Self.key) else {
            return DefaultShortcuts.bindings
        }
        guard let data = object as? Data,
              let file = try? JSONDecoder().decode(StoredFile.self, from: data),
              file.version == Self.version
        else {
            lastLoadIssues = [.corruptData]
            return DefaultShortcuts.bindings
        }

        var bindings = DefaultShortcuts.bindings
        var invalid: [ShortcutLoadIssue] = []
        for action in WindowAction.allCases {
            guard let entry = file.bindings[action.rawValue] else { continue }
            switch entry {
            case .cleared:
                bindings[action] = nil
            case .combo(let combo) where ShortcutValidator.validate(combo):
                bindings[action] = combo
            case .combo, .malformed:
                invalid.append(.invalidModifiers(action))
            }
        }

        // 정리 결과에 겹침이 있으면 선언 순서 뒤쪽 동작을 지운다(같은 조합 동시 등록 방지).
        var duplicates: [ShortcutLoadIssue] = []
        var seen: Set<KeyCombo> = []
        for action in WindowAction.allCases {
            guard let combo = bindings[action] else { continue }
            if seen.insert(combo).inserted == false {
                bindings[action] = nil
                duplicates.append(.duplicateCleared(action))
            }
        }

        lastLoadIssues = invalid + duplicates
        return bindings
    }

    /// 14종 전부를 명시 기록한다(지운 동작은 `null`).
    public func save(_ bindings: ShortcutBindings) {
        var entries: [String: StoredCombo?] = [:]
        for action in WindowAction.allCases {
            // 서브스크립트에 nil을 대입하면 키가 지워지므로 updateValue로 `null`을 명시 기록한다.
            entries.updateValue(bindings[action].map(StoredCombo.init), forKey: action.rawValue)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(SavedFile(version: Self.version, bindings: entries)) else { return }
        defaults.set(data, forKey: Self.key)
    }

    /// 기본값 14종을 명시 기록한다(키 삭제가 아님).
    public func restoreDefaults() {
        save(DefaultShortcuts.bindings)
    }
}

// MARK: - 저장 형식

private struct StoredCombo: Codable {
    let keyCode: UInt32
    let modifiers: [String]

    init(_ combo: KeyCombo) {
        keyCode = combo.keyCode
        modifiers = combo.modifiers.names
    }
}

private struct SavedFile: Encodable {
    let version: Int
    let bindings: [String: StoredCombo?]
}

/// 항목 하나가 깨져도 파일 전체를 버리지 않도록 항목 단위로 관대하게 읽는다.
private enum StoredEntry: Decodable {
    case cleared
    case combo(KeyCombo)
    case malformed

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .cleared
        } else if let stored = try? container.decode(StoredCombo.self),
                  let modifiers = ModifierSet(names: stored.modifiers) {
            self = .combo(KeyCombo(keyCode: stored.keyCode, modifiers: modifiers))
        } else {
            self = .malformed
        }
    }
}

private struct StoredFile: Decodable {
    let version: Int
    let bindings: [String: StoredEntry]
}
