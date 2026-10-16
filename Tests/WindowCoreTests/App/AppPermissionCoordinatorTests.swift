import XCTest
import WindowCore

final class AppPermissionCoordinatorTests: XCTestCase {
    func testDeniedStartupStartsNonAccessibilityFeatures() throws {
        let registry = FeatureRegistry()
        let a = AppFakeFeature("A", requiresAccessibility: true)
        let b = AppFakeFeature("B", requiresAccessibility: false)
        try registry.register(a)
        try registry.register(b)
        let coordinator = AppPermissionCoordinator(registry: registry)

        let result = coordinator.check(trusted: false)

        XCTAssertEqual(result.state, .denied)
        XCTAssertNil(result.transition)
        XCTAssertFalse(result.needsMenuRebuild)
        XCTAssertEqual(result.nextInterval, 2.0)
        XCTAssertEqual(registry.runningFeatureIDs, ["B"])
        XCTAssertEqual(a.startCount, 0)
    }

    func testGrantedTickRetriesFailedFeature() throws {
        let registry = FeatureRegistry()
        let a = AppFakeFeature("A", requiresAccessibility: true, failsStart: true)
        try registry.register(a)
        let coordinator = AppPermissionCoordinator(registry: registry)

        let first = coordinator.check(trusted: true)
        XCTAssertEqual(first.transition, .becameGranted)
        XCTAssertEqual(registry.failedFeatureIDs, ["A"])

        a.shouldFailStart = false
        let second = coordinator.check(trusted: true)
        XCTAssertNil(second.transition)
        XCTAssertFalse(second.needsMenuRebuild)
        XCTAssertEqual(registry.runningFeatureIDs, ["A"])
        XCTAssertEqual(registry.failedFeatureIDs, [])
        XCTAssertEqual(a.startCount, 2)
    }

    func testCheckResultReportsTransitionAndInterval() {
        let coordinator = AppPermissionCoordinator(registry: FeatureRegistry())

        XCTAssertEqual(
            coordinator.check(trusted: false),
            AppPermissionCheck(state: .denied, transition: nil, nextInterval: 2.0, needsMenuRebuild: false)
        )
        XCTAssertEqual(
            coordinator.check(trusted: true),
            AppPermissionCheck(state: .granted, transition: .becameGranted, nextInterval: 10.0, needsMenuRebuild: true)
        )
        XCTAssertEqual(
            coordinator.check(trusted: true),
            AppPermissionCheck(state: .granted, transition: nil, nextInterval: 10.0, needsMenuRebuild: false)
        )
    }

    func testRevokeTickStopsAccessibilityFeatures() throws {
        let registry = FeatureRegistry()
        let a = AppFakeFeature("A", requiresAccessibility: true)
        let b = AppFakeFeature("B", requiresAccessibility: false)
        try registry.register(a)
        try registry.register(b)
        let coordinator = AppPermissionCoordinator(registry: registry)
        coordinator.check(trusted: true)

        let result = coordinator.check(trusted: false)

        XCTAssertEqual(result.transition, .becameRevoked)
        XCTAssertTrue(result.needsMenuRebuild)
        XCTAssertEqual(result.nextInterval, 2.0)
        XCTAssertEqual(registry.runningFeatureIDs, ["B"])
        XCTAssertEqual(a.stopCount, 1)
        XCTAssertEqual(b.stopCount, 0)
    }

    // 
    func testStateReflectsLatestCheck() {
        let coordinator = AppPermissionCoordinator(registry: FeatureRegistry())
        XCTAssertNil(coordinator.state)

        for trusted in [false, true, true, false] {
            let result = coordinator.check(trusted: trusted)
            XCTAssertEqual(coordinator.state, result.state)
        }
        XCTAssertEqual(coordinator.state, .denied)
    }
}
