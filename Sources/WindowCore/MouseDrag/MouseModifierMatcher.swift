import Foundation

/// 수정자 정확 일치 판정 (원본 `_IsMoveEvent` 재현).
public enum MouseModifierMatcher {
    /// 필요한 수정자가 모두 눌려 있고 나머지 수정자·CapsLock이 하나도 없을 때만 일치. 이동이 우선한다.
    /// 수정자 0개 설정은 어떤 입력과도 일치하지 않는다.
    public static func action(for flags: UInt64, settings: MouseDragSettings) -> MouseAction? {
        guard flags & MouseModifierSet.capsLockFlag == 0 else { return nil }
        let pressed = MouseModifierSet(cgEventFlags: flags)
        guard !pressed.isEmpty else { return nil }
        if pressed == settings.moveModifiers { return .move }
        if pressed == settings.resizeModifiers { return .resize }
        return nil
    }
}
