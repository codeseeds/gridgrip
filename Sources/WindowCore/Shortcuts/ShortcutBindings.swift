import Foundation

/// 동작별 단축키. nil = 사용자가 지운 상태.
/// 저장 형식(`shortcuts.v1` JSON)은 `ShortcutStore`가 동작 이름 문자열 키로 직접 인코딩한다.
public struct ShortcutBindings: Equatable {
    private var map: [WindowAction: KeyCombo]

    public init(_ map: [WindowAction: KeyCombo?]) {
        self.map = map.compactMapValues { $0 }
    }

    public subscript(action: WindowAction) -> KeyCombo? {
        get { map[action] }
        set { map[action] = newValue }
    }
}
