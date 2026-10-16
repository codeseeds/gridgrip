import XCTest
import WindowCore

final class GeneralSettingsTests: XCTestCase {
    private let selfID = "com.blackpet.GridGrip"

    func testToggleExcluded() {
        var settings = GeneralSettings()
        XCTAssertTrue(settings.toggleExcluded("com.apple.Safari", selfBundleID: selfID))
        XCTAssertEqual(settings.excludedBundleIDs, ["com.apple.Safari"])
        XCTAssertTrue(settings.toggleExcluded("com.apple.Safari", selfBundleID: selfID))
        XCTAssertEqual(settings.excludedBundleIDs, [])
    }

    func testAddExcludedDuplicate() {
        var settings = GeneralSettings(excludedBundleIDs: ["com.apple.dt.Xcode"])
        XCTAssertEqual(settings.addExcluded("COM.APPLE.DT.XCODE", selfBundleID: selfID), .duplicate)
        XCTAssertEqual(settings.excludedBundleIDs, ["com.apple.dt.Xcode"])
        XCTAssertEqual(settings.addExcluded("com.apple.Safari", selfBundleID: selfID), .added)
        XCTAssertEqual(settings.excludedBundleIDs, ["com.apple.dt.Xcode", "com.apple.Safari"])
    }

    func testRemoveExcluded() {
        var settings = GeneralSettings(excludedBundleIDs: ["com.apple.Safari", "com.a"])
        settings.removeExcluded("COM.APPLE.SAFARI")
        XCTAssertEqual(settings.excludedBundleIDs, ["com.a"])
    }

    func testRejectsSelfAndEmpty() {
        var settings = GeneralSettings(excludedBundleIDs: ["com.a"])
        XCTAssertFalse(settings.toggleExcluded(selfID, selfBundleID: selfID))
        XCTAssertFalse(settings.toggleExcluded("", selfBundleID: selfID))
        XCTAssertEqual(settings.addExcluded("COM.BLACKPET.GRIDGRIP", selfBundleID: selfID), .rejectedSelf)
        XCTAssertEqual(settings.addExcluded("", selfBundleID: selfID), .rejectedEmpty)
        XCTAssertEqual(settings.excludedBundleIDs, ["com.a"])
    }

    func testSnapshotFromPolicy() {
        let policy = ActivationPolicy(isPaused: true, excludedBundleIDs: ["com.a"])
        XCTAssertEqual(GeneralSettings(policy: policy), GeneralSettings(isPaused: true, excludedBundleIDs: ["com.a"]))
    }
}
