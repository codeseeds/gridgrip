import Foundation

/// 안내 문구에 넣는 시스템 설정 경로. macOS 버전마다 메뉴 이름이 달라 버전으로 고른다.
/// - macOS 27: 개인정보 보호 및 보안의 "손쉬운 사용"이 "기기 제어 및 데이터 접근"으로 바뀌었다.
/// - macOS 15: 일반의 "로그인 항목"이 "로그인 항목 및 확장 프로그램"으로 바뀌었다.
public enum SystemSettingsPaths {
    public static var currentOSMajorVersion: Int {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion
    }

    public static func accessibilityPermissionName(osMajorVersion: Int = currentOSMajorVersion) -> String {
        osMajorVersion >= 27 ? L10n.tr("Device Control and Data Access") : L10n.tr("Accessibility")
    }

    public static func accessibilityPermission(osMajorVersion: Int = currentOSMajorVersion) -> String {
        L10n.tr("System Settings > Privacy & Security > %@", accessibilityPermissionName(osMajorVersion: osMajorVersion))
    }

    public static func loginItems(osMajorVersion: Int = currentOSMajorVersion) -> String {
        let pane = osMajorVersion >= 15 ? L10n.tr("Login Items & Extensions") : L10n.tr("Login Items")
        return L10n.tr("System Settings > General > %@", pane)
    }
}
