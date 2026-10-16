import Foundation
import XCTest
import WindowCore

final class AppIdentityTests: XCTestCase {
    func testConstants() {
        XCTAssertEqual(AppIdentity.bundleIdentifier, "com.blackpet.GridGrip")
        XCTAssertEqual(AppIdentity.displayName, "GridGrip")
        XCTAssertEqual(AppIdentity.executableName, "GridGrip")
        XCTAssertEqual(AppIdentity.version, "0.2.0")
    }

    func testInfoPlistTemplateMatchesIdentity() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // App
            .deletingLastPathComponent() // WindowCoreTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // 저장소 루트
        let data = try Data(contentsOf: root.appendingPathComponent("Support/Info.plist"))
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )
        XCTAssertEqual(plist["CFBundleIdentifier"] as? String, AppIdentity.bundleIdentifier)
        XCTAssertEqual(plist["CFBundleExecutable"] as? String, AppIdentity.executableName)
        XCTAssertEqual(plist["CFBundleShortVersionString"] as? String, AppIdentity.version)
        XCTAssertEqual(plist["LSUIElement"] as? Bool, true)
        XCTAssertEqual(plist["LSMinimumSystemVersion"] as? String, "13.0")
        XCTAssertEqual(plist["CFBundleDevelopmentRegion"] as? String, "en")
        XCTAssertEqual(plist["CFBundleLocalizations"] as? [String], ["en", "ko"])
        XCTAssertEqual(plist["CFBundlePackageType"] as? String, "APPL")
    }
}
