import Foundation

/// 기본값 복원 정본: 단축키 14종 + 마우스 수정자·창 앞으로 가져오기.
/// 제외 앱·일시정지(`general.v1`·`ActivationPolicy`)·로그인 시 실행은 인자로 받지 않아 바꿀 수 없다.
public enum SettingsDefaultsRestorer {
    public static func restoreAll(engine: ShortcutEngine, mouseStore: MouseDragSettingsStore) throws {
        engine.restoreDefaults()
        try mouseStore.save(.default)
    }
}
