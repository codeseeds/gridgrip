import XCTest
import WindowCore

final class LoginItemPresentationTests: XCTestCase {
    func testMapping() {
        XCTAssertEqual(LoginItemPresentation.make(.enabled),
                       LoginItemPresentation(isChecked: true, isEnabled: true, message: nil, showsOpenSettings: false))
        XCTAssertEqual(LoginItemPresentation.make(.notRegistered),
                       LoginItemPresentation(isChecked: false, isEnabled: true, message: nil, showsOpenSettings: false))
        XCTAssertEqual(LoginItemPresentation.make(.requiresApproval, osMajorVersion: 14),
                       LoginItemPresentation(isChecked: true, isEnabled: true,
                                             message: "Allow it in System Settings > General > Login Items",
                                             showsOpenSettings: true))
        XCTAssertEqual(LoginItemPresentation.make(.notFound),
                       LoginItemPresentation(isChecked: false, isEnabled: false,
                                             message: "Available only when running as an app bundle (.app)",
                                             showsOpenSettings: false))
    }

    func testRequiresApprovalPointsToLoginItemsAndExtensionsFromMacOS15() {
        XCTAssertEqual(LoginItemPresentation.make(.requiresApproval, osMajorVersion: 15).message,
                       "Allow it in System Settings > General > Login Items & Extensions")
    }

    func testResolveStatus() {
        // 번들 밖 실행이면 서비스 상태와 상관없이 notFound.
        XCTAssertEqual(LoginItemStatus.resolve(isBundledApp: false, serviceStatus: .enabled), .notFound)
        // macOS 27 은 한 번도 등록하지 않은 번들 앱에도 notFound 를 돌려준다 → 등록 가능한 상태로 본다.
        XCTAssertEqual(LoginItemStatus.resolve(isBundledApp: true, serviceStatus: .notFound), .notRegistered)
        XCTAssertEqual(LoginItemStatus.resolve(isBundledApp: true, serviceStatus: .enabled), .enabled)
        XCTAssertEqual(LoginItemStatus.resolve(isBundledApp: true, serviceStatus: .notRegistered), .notRegistered)
        XCTAssertEqual(LoginItemStatus.resolve(isBundledApp: true, serviceStatus: .requiresApproval), .requiresApproval)
    }

    func testAfterToggleFailure() {
        let failed = LoginItemPresentation.afterToggle(actual: .notRegistered, errorDescription: "Operation not permitted")
        XCTAssertFalse(failed.isChecked)
        XCTAssertTrue(failed.isEnabled)
        XCTAssertEqual(failed.message, "Couldn't change the login item: Operation not permitted")

        XCTAssertEqual(LoginItemPresentation.afterToggle(actual: .enabled, errorDescription: nil), LoginItemPresentation.make(.enabled))
    }
}
