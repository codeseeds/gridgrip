import Foundation

/// `SMAppService.Status`를 WindowCore 형식으로 미러한 값(WindowCore는 ServiceManagement 금지).
public enum LoginItemStatus: Equatable {
    case enabled
    case notRegistered
    case requiresApproval
    /// 번들 밖 실행(`swift run`) 등으로 서비스를 찾지 못함.
    case notFound
}

/// 메뉴·설정 창 공통 로그인 항목 표시값.
public struct LoginItemPresentation: Equatable {
    public static let requiresApprovalMessage = "시스템 설정 > 일반 > 로그인 항목에서 허용이 필요합니다"
    public static let notBundledMessage = "앱 번들(.app)로 실행할 때만 사용할 수 있습니다"

    public var isChecked: Bool
    public var isEnabled: Bool
    public var message: String?
    public var showsOpenSettings: Bool

    public init(isChecked: Bool, isEnabled: Bool, message: String?, showsOpenSettings: Bool) {
        self.isChecked = isChecked
        self.isEnabled = isEnabled
        self.message = message
        self.showsOpenSettings = showsOpenSettings
    }

    public static func make(_ status: LoginItemStatus) -> LoginItemPresentation {
        switch status {
        case .enabled:
            return LoginItemPresentation(isChecked: true, isEnabled: true, message: nil, showsOpenSettings: false)
        case .notRegistered:
            return LoginItemPresentation(isChecked: false, isEnabled: true, message: nil, showsOpenSettings: false)
        case .requiresApproval:
            return LoginItemPresentation(isChecked: true, isEnabled: true, message: requiresApprovalMessage, showsOpenSettings: true)
        case .notFound:
            return LoginItemPresentation(isChecked: false, isEnabled: false, message: notBundledMessage, showsOpenSettings: false)
        }
    }

    /// 체크는 실제 상태 기준. 오류가 있으면 안내 문구를 실패 문구로 바꾼다.
    public static func afterToggle(actual: LoginItemStatus, errorDescription: String?) -> LoginItemPresentation {
        var presentation = make(actual)
        if let errorDescription {
            presentation.message = "로그인 항목을 바꾸지 못했습니다: \(errorDescription)"
        }
        return presentation
    }
}
