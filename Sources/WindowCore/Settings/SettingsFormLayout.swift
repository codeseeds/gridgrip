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
        case .shortcuts: return L10n.tr("Keyboard Shortcuts")
        case .mouse: return L10n.tr("Move & Resize with Mouse")
        case .excludedApps: return L10n.tr("Excluded Apps")
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
    public static var mouseRows: [(target: SettingsMouseTarget, title: String)] { [(.move, L10n.tr("Move")), (.resize, L10n.tr("Resize"))] }
    public static var bringWindowToFrontTitle: String { L10n.tr("Bring the app to the front when grabbing its window") }

    public static var windowTitle: String { L10n.tr("%@ Settings", AppIdentity.displayName) }
    public static var emptyShortcutPlaceholder: String { L10n.tr("Record Shortcut") }
    public static var recordingPrompt: String { L10n.tr("Press keys…") }
    public static var noModifierMessage: String { L10n.tr("Include at least one of ⌃, ⌥ or ⌘") }
    public static var reservedComboMessage: String { L10n.tr("This shortcut is reserved by the system") }
    public static var registrationFailureMessage: String { L10n.tr("Another app may already be using this shortcut") }
    public static var optionOnlyAdvisory: String { L10n.tr("Shortcuts with only ⌥ (or ⌥⇧) can block typing special characters in other apps") }
    public static var loginItemTitle: String { L10n.tr("Launch at Login") }
    public static var openSystemSettingsTitle: String { L10n.tr("Open System Settings") }
    public static var restoreDefaultsTitle: String { L10n.tr("Restore Defaults…") }
    public static var restoreDefaultsConfirmation: String {
        L10n.tr("Resets keyboard shortcuts, mouse modifiers and bring-to-front to their defaults. Excluded apps and Launch at Login stay as they are.")
    }

    public static func title(for action: WindowAction) -> String {
        switch action {
        case .topLeft: return L10n.tr("Top Left")
        case .top: return L10n.tr("Top")
        case .topRight: return L10n.tr("Top Right")
        case .left: return L10n.tr("Left")
        case .center: return L10n.tr("Center")
        case .right: return L10n.tr("Right")
        case .bottomLeft: return L10n.tr("Bottom Left")
        case .bottom: return L10n.tr("Bottom")
        case .bottomRight: return L10n.tr("Bottom Right")
        case .fill: return L10n.tr("Fill Screen")
        case .previousDisplay: return L10n.tr("Previous Display")
        case .nextDisplay: return L10n.tr("Next Display")
        case .undo: return L10n.tr("Undo")
        case .redo: return L10n.tr("Redo")
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
        case .emptyMoveModifiers, .emptyResizeModifiers: return L10n.tr("Select at least one modifier")
        case .identicalModifiers: return L10n.tr("Move and Resize need different modifier combinations")
        }
    }

    public static func conflictMessage(_ actions: [WindowAction]) -> String {
        L10n.tr("Already used by '%@'", actions.map(title(for:)).joined(separator: "', '"))
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
