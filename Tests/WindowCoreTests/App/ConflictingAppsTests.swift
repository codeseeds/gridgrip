import XCTest
import WindowCore

final class ConflictingAppsTests: XCTestCase {
    func testConflictsDetection() {
        XCTAssertEqual(
            ConflictNoticePolicy.conflicts(runningBundleIDs: ["com.apple.finder", "com.divisiblebyzero.Spectacle"]),
            [.spectacle]
        )
        XCTAssertEqual(
            ConflictNoticePolicy.conflicts(runningBundleIDs: ["com.divisiblebyzero.Spectacle", "de.curioustimes.Window-Mover"]),
            KnownConflictingApp.all
        )
        XCTAssertEqual(KnownConflictingApp.all.count, 2)
        XCTAssertEqual(ConflictNoticePolicy.conflicts(runningBundleIDs: []), [])
    }

    func testShouldShowNotice() {
        XCTAssertTrue(ConflictNoticePolicy.shouldShowNotice(conflicts: [.spectacle], alreadyChecked: false))
        XCTAssertFalse(ConflictNoticePolicy.shouldShowNotice(conflicts: [.spectacle], alreadyChecked: true))
        XCTAssertFalse(ConflictNoticePolicy.shouldShowNotice(conflicts: [], alreadyChecked: false))
        XCTAssertEqual(AppStateKeys.didRunFirstLaunchCheck, "app.didRunFirstLaunchCheck")
    }
}
