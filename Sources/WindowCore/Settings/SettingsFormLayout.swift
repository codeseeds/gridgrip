import Foundation

/// 설정 창 섹션(위에서 아래 순서).
public enum SettingsSection: CaseIterable, Equatable {
    case shortcuts
    case mouse
    case excludedApps
    /// 로그인 시 실행 + 기본값 복원… (제목 없음)
    case general

    public var title: String? {
        switch self {
        case .shortcuts: return "키보드 배치 단축키"
        case .mouse: return "마우스로 창 다루기"
        case .excludedApps: return "이 앱에서는 끄기"
        case .general: return nil
        }
    }
}

/// 마우스 수정자 줄 대상.
public enum SettingsMouseTarget: Equatable {
    case move
    case resize
}

/// 설정 창 구조·문구·경고 대상의 정본. 실제 렌더링은 실행 타깃의 `SettingsWindowController`가 이 값을 그대로 그린다.
public enum SettingsFormLayout {
    public static let sections: [SettingsSection] = SettingsSection.allCases

    /// 7행×2열. 행 단위 좌→우로 `WindowAction` 선언 순서.
    public static let shortcutGrid: [[WindowAction]] = stride(from: 0, to: WindowAction.allCases.count, by: 2).map {
        Array(WindowAction.allCases[$0..<min($0 + 2, WindowAction.allCases.count)])
    }

    public static let mouseModifierOrder: [MouseModifierSet] = [.shift, .fn, .control, .option, .command]
    public static let mouseRows: [(target: SettingsMouseTarget, title: String)] = [(.move, "이동"), (.resize, "크기조정")]
    public static let bringWindowToFrontTitle = "창을 잡을 때 그 앱을 앞으로 가져오기"

    public static let windowTitle = "\(AppIdentity.displayName) 설정"
    public static let emptyShortcutPlaceholder = "단축키 녹화"
    public static let recordingPrompt = "키를 누르세요…"
    public static let noModifierMessage = "⌃·⌥·⌘ 중 하나 이상을 함께 눌러야 합니다"
    public static let reservedComboMessage = "시스템에서 쓰는 단축키라 사용할 수 없습니다"
    public static let registrationFailureMessage = "다른 앱이 이미 사용 중일 수 있습니다"
    public static let optionOnlyAdvisory = "⌥만(또는 ⌥⇧) 쓰는 조합은 다른 앱의 특수문자 입력을 가로챌 수 있습니다"
    public static let loginItemTitle = "로그인 시 실행"
    public static let openSystemSettingsTitle = "시스템 설정 열기"
    public static let restoreDefaultsTitle = "기본값 복원…"
    public static let restoreDefaultsConfirmation =
        "키보드 단축키, 마우스 수정자, 창 앞으로 가져오기를 기본값으로 되돌립니다. 제외 앱 목록과 로그인 시 실행은 그대로 둡니다."

    public static func title(for action: WindowAction) -> String {
        switch action {
        case .topLeft: return "좌상단"
        case .top: return "상단"
        case .topRight: return "우상단"
        case .left: return "좌측"
        case .center: return "가운데"
        case .right: return "우측"
        case .bottomLeft: return "좌하단"
        case .bottom: return "하단"
        case .bottomRight: return "우하단"
        case .fill: return "전체화면 채우기"
        case .previousDisplay: return "왼쪽 모니터로"
        case .nextDisplay: return "오른쪽 모니터로"
        case .undo: return "되돌리기"
        case .redo: return "다시하기"
        }
    }

    /// 모르는 조합(여러 비트)이면 빈 문자열.
    public static func label(for modifier: MouseModifierSet) -> String {
        switch modifier {
        case .shift: return "Shift"
        case .fn: return "Fn"
        case .control: return "Control"
        case .option: return "Option"
        case .command: return "Command"
        default: return ""
        }
    }

    public static func message(for error: MouseDragSettingsError) -> String {
        switch error {
        case .emptyMoveModifiers, .emptyResizeModifiers: return "수정자를 하나 이상 선택해야 합니다"
        case .identicalModifiers: return "이동과 크기조정은 서로 다른 조합이어야 합니다"
        }
    }

    public static func conflictMessage(_ actions: [WindowAction]) -> String {
        "'\(actions.map(title(for:)).joined(separator: "', '"))'에서 이미 쓰는 단축키입니다"
    }

    /// 적용은 되지만 알려 둘 점이 있는 조합의 안내(⌥ 단독·⌥⇧ 조합).
    public static func advisory(for combo: KeyCombo) -> String? {
        let modifiers = combo.modifiers
        guard modifiers.contains(.option), modifiers.isSubset(of: [.option, .shift]) else { return nil }
        return optionOnlyAdvisory
    }

    /// 등록 실패 경고를 붙일 동작(`WindowAction.allCases` 순서).
    public static func warningActions(registrationFailures: Set<WindowAction>) -> [WindowAction] {
        WindowAction.allCases.filter(registrationFailures.contains)
    }
}
