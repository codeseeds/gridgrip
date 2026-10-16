import Foundation

public enum SettingsMouseToggleResult: Equatable {
    case accepted(MouseDragSettings)
    /// 저장하지 말고 체크를 원래대로 되돌린다.
    case rejected(MouseDragSettingsError)
}

/// 체크박스 1개 변경 → 변경안 생성 → `MouseDragSettings.validate()`로 판정. 규칙을 다시 구현하지 않는다.
public enum MouseModifierToggle {
    public static func apply(_ current: MouseDragSettings,
                             target: SettingsMouseTarget,
                             modifier: MouseModifierSet,
                             isOn: Bool) -> SettingsMouseToggleResult {
        var proposed = current
        switch target {
        case .move: toggle(&proposed.moveModifiers, modifier, isOn)
        case .resize: toggle(&proposed.resizeModifiers, modifier, isOn)
        }
        if let error = proposed.validate().first { return .rejected(error) }
        return .accepted(proposed)
    }

    private static func toggle(_ set: inout MouseModifierSet, _ modifier: MouseModifierSet, _ isOn: Bool) {
        if isOn {
            set.insert(modifier)
        } else {
            set.remove(modifier)
        }
    }
}
