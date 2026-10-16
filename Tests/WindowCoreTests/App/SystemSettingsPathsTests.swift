import XCTest
import WindowCore

final class SystemSettingsPathsTests: XCTestCase {
    func testAccessibilityPermissionNameChangesInMacOS27() {
        XCTAssertEqual(SystemSettingsPaths.accessibilityPermissionName(osMajorVersion: 13), "Accessibility")
        XCTAssertEqual(SystemSettingsPaths.accessibilityPermissionName(osMajorVersion: 26), "Accessibility")
        XCTAssertEqual(SystemSettingsPaths.accessibilityPermissionName(osMajorVersion: 27), "Device Control and Data Access")
        XCTAssertEqual(SystemSettingsPaths.accessibilityPermissionName(osMajorVersion: 28), "Device Control and Data Access")
    }

    func testAccessibilityPermissionPath() {
        XCTAssertEqual(SystemSettingsPaths.accessibilityPermission(osMajorVersion: 26),
                       "System Settings > Privacy & Security > Accessibility")
        XCTAssertEqual(SystemSettingsPaths.accessibilityPermission(osMajorVersion: 27),
                       "System Settings > Privacy & Security > Device Control and Data Access")
    }

    func testLoginItemsPathChangesInMacOS15() {
        XCTAssertEqual(SystemSettingsPaths.loginItems(osMajorVersion: 13), "System Settings > General > Login Items")
        XCTAssertEqual(SystemSettingsPaths.loginItems(osMajorVersion: 14), "System Settings > General > Login Items")
        XCTAssertEqual(SystemSettingsPaths.loginItems(osMajorVersion: 15),
                       "System Settings > General > Login Items & Extensions")
        XCTAssertEqual(SystemSettingsPaths.loginItems(osMajorVersion: 27),
                       "System Settings > General > Login Items & Extensions")
    }

    func testPathsAreTranslatedInKorean() throws {
        let ko = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Support/Localization/ko.lproj")
        L10n.bundle = try XCTUnwrap(Bundle(url: ko))
        defer { L10n.bundle = .main }
        XCTAssertEqual(SystemSettingsPaths.accessibilityPermission(osMajorVersion: 26),
                       "시스템 설정 > 개인정보 보호 및 보안 > 손쉬운 사용")
        XCTAssertEqual(SystemSettingsPaths.accessibilityPermission(osMajorVersion: 27),
                       "시스템 설정 > 개인정보 보호 및 보안 > 기기 제어 및 데이터 접근")
        XCTAssertEqual(SystemSettingsPaths.loginItems(osMajorVersion: 14), "시스템 설정 > 일반 > 로그인 항목")
        XCTAssertEqual(SystemSettingsPaths.loginItems(osMajorVersion: 15), "시스템 설정 > 일반 > 로그인 항목 및 확장 프로그램")
    }
}
