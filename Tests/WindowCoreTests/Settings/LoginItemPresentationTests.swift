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

    func testAfterToggleFailure() {
        let failed = LoginItemPresentation.afterToggle(actual: .notRegistered, errorDescription: "Operation not permitted")
        XCTAssertFalse(failed.isChecked)
        XCTAssertTrue(failed.isEnabled)
        XCTAssertEqual(failed.message, "Couldn't change the login item: Operation not permitted")

        XCTAssertEqual(LoginItemPresentation.afterToggle(actual: .enabled, errorDescription: nil), LoginItemPresentation.make(.enabled))
    }
}
