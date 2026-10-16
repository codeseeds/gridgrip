import Foundation

/// 수정자 규칙 검사와 겹침 판정.
public enum ShortcutValidator {
    /// 하드웨어 가상 키코드 상한(0x00~0x7F). 범위 밖은 쓸 수 없는 조합으로 본다.
    public static let maxKeyCode: UInt32 = 0x7F

    /// 전역 단축키로 가로채면 모든 앱의 기본 동작이 막히는 시스템 필수 조합.
    /// 기본값 ⌥⌘Z·⇧⌥⌘Z는 수정자가 달라 여기에 걸리지 않는다.
    public static let reservedCombos: Set<KeyCombo> = [
        KeyCombo(keyCode: 0x0C, modifiers: [.command]),            // ⌘Q 종료
        KeyCombo(keyCode: 0x0D, modifiers: [.command]),            // ⌘W 창 닫기
        KeyCombo(keyCode: 0x08, modifiers: [.command]),            // ⌘C 복사
        KeyCombo(keyCode: 0x09, modifiers: [.command]),            // ⌘V 붙여넣기
        KeyCombo(keyCode: 0x07, modifiers: [.command]),            // ⌘X 잘라내기
        KeyCombo(keyCode: 0x06, modifiers: [.command]),            // ⌘Z 실행 취소
        KeyCombo(keyCode: 0x06, modifiers: [.shift, .command]),    // ⇧⌘Z 다시 실행
        KeyCombo(keyCode: 0x00, modifiers: [.command]),            // ⌘A 전체 선택
        KeyCombo(keyCode: 0x01, modifiers: [.command]),            // ⌘S 저장
        KeyCombo(keyCode: 0x30, modifiers: [.command]),            // ⌘Tab 앱 전환
        KeyCombo(keyCode: 0x31, modifiers: [.command]),            // ⌘Space Spotlight
        KeyCombo(keyCode: 0x31, modifiers: [.control]),            // ⌃Space 입력 소스 전환
        KeyCombo(keyCode: 0x04, modifiers: [.command]),            // ⌘H 가리기
        KeyCombo(keyCode: 0x2E, modifiers: [.command]),            // ⌘M 최소화
        KeyCombo(keyCode: 0x35, modifiers: [.option, .command]),   // ⌥⌘Esc 강제 종료
    ]

    /// 쓸 수 있는 조합이면 true: control·option·command 중 최소 1개(수정자 0개·Shift 단독은 무효),
    /// 키코드가 0x7F 이하, 시스템 필수 조합이 아님.
    public static func validate(_ combo: KeyCombo) -> Bool {
        !combo.modifiers.isDisjoint(with: [.control, .option, .command])
            && combo.keyCode <= maxKeyCode
            && !isReserved(combo)
    }

    /// 시스템 필수 조합이면 true. 설정 화면이 거부 사유를 구분해 안내할 때 쓴다.
    public static func isReserved(_ combo: KeyCombo) -> Bool {
        reservedCombos.contains(combo)
    }

    /// `combo`를 `action`에 넣을 때 같은 조합을 쓰는 다른 동작(선언 순서). 자기 자신·nil은 제외.
    public static func conflicts(for combo: KeyCombo, action: WindowAction, in bindings: ShortcutBindings) -> [WindowAction] {
        WindowAction.allCases.filter { $0 != action && bindings[$0] == combo }
    }
}
