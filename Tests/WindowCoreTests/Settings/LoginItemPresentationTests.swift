import XCTest
import WindowCore

final class LoginItemPresentationTests: XCTestCase {
    func testMapping() {
        XCTAssertEqual(LoginItemPresentation.make(.enabled),
                       LoginItemPresentation(isChecked: true, isEnabled: true, message: nil, showsOpenSettings: false))
        XCTAssertEqual(LoginItemPresentation.make(.notRegistered),
                       LoginItemPresentation(isChecked: false, isEnabled: true, message: nil, showsOpenSettings: false))
        XCTAssertEqual(LoginItemPresentation.make(.requiresApproval),
                       LoginItemPresentation(isChecked: true, isEnabled: true,
                                             message: "시스템 설정 > 일반 > 로그인 항목에서 허용이 필요합니다",
                                             showsOpenSettings: true))
        XCTAssertEqual(LoginItemPresentation.make(.notFound),
                       LoginItemPresentation(isChecked: false, isEnabled: false,
                                             message: "앱 번들(.app)로 실행할 때만 사용할 수 있습니다",
                                             showsOpenSettings: false))
    }

    func testAfterToggleFailure() {
        let failed = LoginItemPresentation.afterToggle(actual: .notRegistered, errorDescription: "Operation not permitted")
        XCTAssertFalse(failed.isChecked)
        XCTAssertTrue(failed.isEnabled)
        XCTAssertEqual(failed.message, "로그인 항목을 바꾸지 못했습니다: Operation not permitted")

        XCTAssertEqual(LoginItemPresentation.afterToggle(actual: .enabled, errorDescription: nil), LoginItemPresentation.make(.enabled))
    }
}
