import XCTest
import WindowCore

final class SettingsActivationSyncTests: XCTestCase {
    private var suite: SettingsTestDefaults!
    private var registrar: SettingsFakeRegistrar!

    override func setUp() {
        super.setUp()
        suite = SettingsTestDefaults()
        registrar = SettingsFakeRegistrar()
    }

    override func tearDown() {
        suite.tearDown()
        suite = nil
        registrar = nil
        super.tearDown()
    }

    private var store: GeneralSettingsStore { GeneralSettingsStore(defaults: suite.defaults) }

    func testCorruptedStartup() {
        suite.defaults.set("not json", forKey: GeneralSettingsStore.key)
        let policy = ActivationPolicy()
        let engine = suite.makeEngine(registrar: registrar)

        SettingsActivationSync.load(store, into: policy)
        SettingsActivationSync.syncSuspendReasons(engine: engine, policy: policy, frontmostBundleID: nil)
        engine.start()

        XCTAssertFalse(policy.isPaused)
        XCTAssertTrue(engine.suspendReasons.isEmpty)
        XCTAssertEqual(registrar.registerCount, WindowAction.allCases.count)
    }

    func testLoadIntoPolicy() {
        store.save(GeneralSettings(isPaused: true, excludedBundleIDs: ["com.apple.dt.Xcode"]))
        let policy = ActivationPolicy()
        SettingsActivationSync.load(store, into: policy)
        XCTAssertTrue(policy.isPaused)
        XCTAssertEqual(policy.excludedBundleIDs, ["com.apple.dt.Xcode"])
    }

    func testPausedReason() {
        let engine = suite.makeEngine(registrar: registrar)
        let policy = ActivationPolicy()

        policy.update(isPaused: true)
        SettingsActivationSync.syncSuspendReasons(engine: engine, policy: policy, frontmostBundleID: nil)
        XCTAssertTrue(engine.suspendReasons.contains(.userPaused))

        policy.update(isPaused: false)
        SettingsActivationSync.syncSuspendReasons(engine: engine, policy: policy, frontmostBundleID: nil)
        XCTAssertFalse(engine.suspendReasons.contains(.userPaused))
    }

    func testExcludedFrontmostReason() {
        let engine = suite.makeEngine(registrar: registrar)
        let policy = ActivationPolicy(excludedBundleIDs: ["com.apple.dt.Xcode"])

        SettingsActivationSync.syncSuspendReasons(engine: engine, policy: policy, frontmostBundleID: "com.apple.dt.xcode")
        XCTAssertTrue(engine.suspendReasons.contains(.excludedAppFrontmost))

        SettingsActivationSync.syncSuspendReasons(engine: engine, policy: policy, frontmostBundleID: "com.apple.Safari")
        XCTAssertFalse(engine.suspendReasons.contains(.excludedAppFrontmost))

        SettingsActivationSync.syncSuspendReasons(engine: engine, policy: policy, frontmostBundleID: "com.apple.dt.Xcode")
        SettingsActivationSync.syncSuspendReasons(engine: engine, policy: policy, frontmostBundleID: nil)
        XCTAssertFalse(engine.suspendReasons.contains(.excludedAppFrontmost))
    }

    func testDoesNotTouchRecording() {
        let engine = suite.makeEngine(registrar: registrar)
        engine.suspend(.recording)
        SettingsActivationSync.syncSuspendReasons(engine: engine, policy: ActivationPolicy(), frontmostBundleID: "com.apple.Safari")
        XCTAssertEqual(engine.suspendReasons, [.recording])
    }

    func testStartsPaused() {
        store.save(GeneralSettings(isPaused: true))
        let policy = ActivationPolicy()
        let engine = suite.makeEngine(registrar: registrar)

        SettingsActivationSync.load(store, into: policy)
        SettingsActivationSync.syncSuspendReasons(engine: engine, policy: policy, frontmostBundleID: nil)
        engine.start()
        XCTAssertEqual(registrar.registerCount, 0)

        policy.update(isPaused: false)
        SettingsActivationSync.syncSuspendReasons(engine: engine, policy: policy, frontmostBundleID: nil)
        XCTAssertEqual(registrar.registerCount, WindowAction.allCases.count)
    }

    func testStartsWithExcludedFrontmost() {
        let policy = ActivationPolicy(excludedBundleIDs: ["com.apple.Safari"])
        let engine = suite.makeEngine(registrar: registrar)

        SettingsActivationSync.syncSuspendReasons(engine: engine, policy: policy, frontmostBundleID: "com.apple.Safari")
        engine.start()

        XCTAssertEqual(registrar.registerCount, 0)
        XCTAssertEqual(engine.suspendReasons, [.excludedAppFrontmost])
    }

    func testIdempotent() {
        let engine = suite.makeEngine(registrar: registrar)
        engine.start()
        let policy = ActivationPolicy()
        registrar.calls = []

        SettingsActivationSync.syncSuspendReasons(engine: engine, policy: policy, frontmostBundleID: nil)
        SettingsActivationSync.syncSuspendReasons(engine: engine, policy: policy, frontmostBundleID: nil)
        XCTAssertEqual(registrar.calls, [])

        policy.update(isPaused: true)
        SettingsActivationSync.syncSuspendReasons(engine: engine, policy: policy, frontmostBundleID: nil)
        SettingsActivationSync.syncSuspendReasons(engine: engine, policy: policy, frontmostBundleID: nil)
        XCTAssertEqual(registrar.calls, [.unregisterAll])
    }

    func testExcludedWhilePaused() {
        store.save(GeneralSettings(isPaused: true, excludedBundleIDs: ["com.apple.Safari"]))
        let policy = ActivationPolicy()
        SettingsActivationSync.load(store, into: policy)

        XCTAssertTrue(policy.isExcluded(bundleIdentifier: "com.apple.Safari"))
        XCTAssertFalse(policy.isExcluded(bundleIdentifier: "com.apple.finder"))
        XCTAssertFalse(policy.isExcluded(bundleIdentifier: nil))
        XCTAssertTrue(policy.isPaused)
    }

    // 값 변경 → `general.v1` 저장 + 엔진 사유 반영
    func testPersistAndSyncOnChange() {
        let policy = ActivationPolicy()
        let engine = suite.makeEngine(registrar: registrar)
        engine.start()
        var changes = 0
        SettingsActivationSync.connect(policy: policy, store: store, engine: engine,
                                       frontmostBundleID: { "com.apple.Safari" },
                                       onChange: { changes += 1 })

        policy.update(isPaused: true)
        XCTAssertEqual(store.load(), GeneralSettings(isPaused: true))
        XCTAssertEqual(engine.suspendReasons, [.userPaused])

        policy.update(isPaused: false, excludedBundleIDs: ["com.apple.Safari"])
        XCTAssertEqual(store.load(), GeneralSettings(isPaused: false, excludedBundleIDs: ["com.apple.Safari"]))
        XCTAssertEqual(engine.suspendReasons, [.excludedAppFrontmost])
        XCTAssertEqual(changes, 2)
    }
}
