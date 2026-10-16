import XCTest
import WindowCore

final class ActivationPolicyTests: XCTestCase {
    func testDefaultsAndExclusion() {
        let policy = ActivationPolicy()
        XCTAssertFalse(policy.isPaused)
        XCTAssertEqual(policy.excludedBundleIDs, [])

        let excluding = ActivationPolicy(excludedBundleIDs: ["com.Foo.App"])
        XCTAssertTrue(excluding.isExcluded(bundleIdentifier: "com.foo.app"))
        XCTAssertFalse(excluding.isExcluded(bundleIdentifier: "com.bar"))
        XCTAssertFalse(excluding.isExcluded(bundleIdentifier: nil))
    }

    func testUpdateNotifiesOnlyOnChange() {
        let policy = ActivationPolicy()
        var calls: [Int] = []
        policy.addObserver { calls.append(1) }
        policy.addObserver { calls.append(2) }

        policy.update(isPaused: false)
        XCTAssertEqual(calls, [])

        policy.update(isPaused: true)
        XCTAssertEqual(calls, [1, 2])
        XCTAssertTrue(policy.isPaused)

        policy.update(isPaused: true, excludedBundleIDs: ["b", "a"])
        XCTAssertEqual(calls, [1, 2, 1, 2])
        XCTAssertEqual(policy.excludedBundleIDs, ["b", "a"])

        policy.update(excludedBundleIDs: ["b", "a"])
        XCTAssertEqual(calls, [1, 2, 1, 2])

        policy.update()
        XCTAssertEqual(calls, [1, 2, 1, 2])
    }
}
