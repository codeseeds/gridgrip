import XCTest
import WindowCore

final class FeatureRegistryTests: XCTestCase {
    private func makeRegistry(_ features: [AppFakeFeature]) throws -> FeatureRegistry {
        let registry = FeatureRegistry()
        for feature in features { try registry.register(feature) }
        return registry
    }

    func testStartFailureIsIsolated() throws {
        let a = AppFakeFeature("A"), b = AppFakeFeature("B", failsStart: true), c = AppFakeFeature("C")
        let registry = try makeRegistry([a, b, c])
        var failures: [String] = []
        registry.onStartFailure = { id, _ in failures.append(id) }

        registry.apply(permission: .granted)

        XCTAssertEqual(registry.runningFeatureIDs, ["A", "C"])
        XCTAssertEqual(registry.failedFeatureIDs, ["B"])
        XCTAssertEqual(a.startCount, 1)
        XCTAssertEqual(c.startCount, 1)
        XCTAssertEqual(failures, ["B"])
    }

    func testFailedFeatureRetriedOnNextApply() throws {
        let a = AppFakeFeature("A"), b = AppFakeFeature("B", failsStart: true), c = AppFakeFeature("C")
        let registry = try makeRegistry([a, b, c])
        registry.apply(permission: .granted)

        b.shouldFailStart = false
        registry.apply(permission: .granted)

        XCTAssertEqual(registry.runningFeatureIDs, ["A", "B", "C"])
        XCTAssertEqual(registry.failedFeatureIDs, [])
        XCTAssertEqual(a.startCount, 1)
        XCTAssertEqual(c.startCount, 1)
        XCTAssertEqual(b.startCount, 2)
    }

    func testDuplicateIDThrows() throws {
        let first = AppFakeFeature("A"), second = AppFakeFeature("A")
        let registry = FeatureRegistry()
        try registry.register(first)

        XCTAssertThrowsError(try registry.register(second)) { error in
            XCTAssertEqual(error as? FeatureRegistryError, .duplicateID("A"))
        }
        registry.apply(permission: .granted)
        XCTAssertEqual(first.startCount + second.startCount, 1)
        XCTAssertEqual(registry.runningFeatureIDs, ["A"])
    }

    func testRegisterAfterFirstApplyThrows() throws {
        let a = AppFakeFeature("A"), b = AppFakeFeature("B")
        let registry = try makeRegistry([a])
        registry.apply(permission: .denied)

        XCTAssertThrowsError(try registry.register(b)) { error in
            XCTAssertEqual(error as? FeatureRegistryError, .registrationClosed)
        }
        registry.apply(permission: .granted)
        XCTAssertEqual(b.startCount, 0)
        XCTAssertFalse(registry.runningFeatureIDs.contains("B"))
    }

    func testDeniedDropsFailedAccessibilityFeature() throws {
        let a = AppFakeFeature("A", requiresAccessibility: true, failsStart: true)
        let registry = try makeRegistry([a])
        registry.apply(permission: .granted)
        XCTAssertEqual(registry.failedFeatureIDs, ["A"])

        registry.apply(permission: .denied)
        registry.apply(permission: .denied)
        XCTAssertEqual(a.startCount, 1)
        XCTAssertEqual(registry.failedFeatureIDs, [])
        XCTAssertEqual(registry.runningFeatureIDs, [])

        a.shouldFailStart = false
        registry.apply(permission: .granted)
        XCTAssertEqual(a.startCount, 2)
        XCTAssertEqual(registry.runningFeatureIDs, ["A"])
    }

    func testDeniedRetriesNonAccessibilityFeature() throws {
        let b = AppFakeFeature("B", requiresAccessibility: false, failsStart: true)
        let registry = try makeRegistry([b])
        registry.apply(permission: .denied)
        XCTAssertEqual(registry.failedFeatureIDs, ["B"])

        b.shouldFailStart = false
        registry.apply(permission: .denied)
        XCTAssertEqual(registry.failedFeatureIDs, [])
        XCTAssertEqual(registry.runningFeatureIDs, ["B"])
        XCTAssertEqual(b.startCount, 2)
    }

    func testStartsInRegistrationOrder() throws {
        let journal = AppFakeFeature.Journal()
        let registry = try makeRegistry(["A", "B", "C"].map { AppFakeFeature($0, journal: journal) })

        registry.apply(permission: .granted)

        XCTAssertEqual(journal.entries, ["start:A", "start:B", "start:C"])
    }

    func testDeniedStartsOnlyNonAccessibilityFeatures() throws {
        let a = AppFakeFeature("A", requiresAccessibility: true)
        let b = AppFakeFeature("B", requiresAccessibility: false)
        let registry = try makeRegistry([a, b])

        registry.apply(permission: .denied)

        XCTAssertEqual(registry.runningFeatureIDs, ["B"])
        XCTAssertEqual(a.startCount, 0)
    }

    func testRevokeStopsAccessibilityFeaturesInReverse() throws {
        let journal = AppFakeFeature.Journal()
        let registry = try makeRegistry([
            AppFakeFeature("A", requiresAccessibility: true, journal: journal),
            AppFakeFeature("B", requiresAccessibility: false, journal: journal),
            AppFakeFeature("C", requiresAccessibility: true, journal: journal),
        ])
        registry.apply(permission: .granted)
        journal.entries.removeAll()

        registry.apply(permission: .denied)

        XCTAssertEqual(journal.entries, ["stop:C", "stop:A"])
        XCTAssertEqual(registry.runningFeatureIDs, ["B"])
    }

    func testApplyIsIdempotent() throws {
        let a = AppFakeFeature("A", requiresAccessibility: true)
        let b = AppFakeFeature("B", requiresAccessibility: false)
        let registry = try makeRegistry([a, b])

        registry.apply(permission: .granted)
        registry.apply(permission: .granted)
        XCTAssertEqual(a.startCount, 1)
        XCTAssertEqual(b.startCount, 1)

        registry.apply(permission: .denied)
        let stopsAfterFirstDenied = a.stopCount + b.stopCount
        registry.apply(permission: .denied)
        XCTAssertEqual(a.stopCount + b.stopCount, stopsAfterFirstDenied)
        XCTAssertEqual(a.startCount, 1)
        XCTAssertEqual(b.startCount, 1)
    }

    func testStopAllReverseOrder() throws {
        let journal = AppFakeFeature.Journal()
        let d = AppFakeFeature("D", failsStart: true, journal: journal)
        let registry = try makeRegistry(["A", "B", "C"].map { AppFakeFeature($0, journal: journal) } + [d])
        registry.apply(permission: .granted)
        XCTAssertEqual(registry.failedFeatureIDs, ["D"])
        journal.entries.removeAll()

        registry.stopAll()

        XCTAssertEqual(journal.entries, ["stop:C", "stop:B", "stop:A"])
        XCTAssertEqual(registry.runningFeatureIDs, [])
        XCTAssertEqual(registry.failedFeatureIDs, [])
        XCTAssertEqual(d.stopCount, 0)
    }
}
