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
    public static func requiresApprovalMessage(osMajorVersion: Int = SystemSettingsPaths.currentOSMajorVersion) -> String {
        L10n.tr("Allow it in %@", SystemSettingsPaths.loginItems(osMajorVersion: osMajorVersion))
    }

    public static var notBundledMessage: String { L10n.tr("Available only when running as an app bundle (.app)") }

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

    public static func make(_ status: LoginItemStatus,
                            osMajorVersion: Int = SystemSettingsPaths.currentOSMajorVersion) -> LoginItemPresentation {
        switch status {
        case .enabled:
            return LoginItemPresentation(isChecked: true, isEnabled: true, message: nil, showsOpenSettings: false)
        case .notRegistered:
            return LoginItemPresentation(isChecked: false, isEnabled: true, message: nil, showsOpenSettings: false)
        case .requiresApproval:
            return LoginItemPresentation(isChecked: true, isEnabled: true, message: requiresApprovalMessage(osMajorVersion: osMajorVersion), showsOpenSettings: true)
        case .notFound:
            return LoginItemPresentation(isChecked: false, isEnabled: false, message: notBundledMessage, showsOpenSettings: false)
        }
    }

    /// 체크는 실제 상태 기준. 오류가 있으면 안내 문구를 실패 문구로 바꾼다.
    public static func afterToggle(actual: LoginItemStatus, errorDescription: String?) -> LoginItemPresentation {
        var presentation = make(actual)
        if let errorDescription {
            presentation.message = L10n.tr("Couldn't change the login item: %@", errorDescription)
        }
        return presentation
    }
}
