import XCTest
import WindowCore

final class ShortcutsFeatureTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var registrar: ShortcutsFakeRegistrar!
    private var engine: ShortcutEngine!

    override func setUp() {
        super.setUp()
        suiteName = "WindowCoreTests.Shortcuts.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        registrar = ShortcutsFakeRegistrar()
        engine = ShortcutEngine(store: ShortcutStore(defaults: defaults), registrar: registrar, dispatcher: ActionDispatcher())
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        engine = nil
        registrar = nil
        defaults = nil
        super.tearDown()
    }

    func testIdentityAndRequiresAccessibility() {
        let feature = ShortcutsFeature(engine: engine)
        XCTAssertEqual(feature.featureID, "shortcuts")
        XCTAssertTrue(feature.requiresAccessibility)
    }

    func testStartStopDelegatesToEngine() throws {
        let feature = ShortcutsFeature(engine: engine)

        XCTAssertNoThrow(try feature.start())
        XCTAssertTrue(engine.isStarted)
        XCTAssertEqual(registrar.registerCalls.count, 14)

        registrar.calls.removeAll()
        feature.stop()
        XCTAssertEqual(registrar.calls, [.unregisterAll])
        XCTAssertFalse(engine.isStarted)
    }

    func testRegistryAppliesPermission() throws {
        let registry = FeatureRegistry()
        try registry.register(ShortcutsFeature(engine: engine))

        registry.apply(permission: .denied)
        XCTAssertEqual(registrar.registerCalls.count, 0)
        XCTAssertFalse(registry.runningFeatureIDs.contains("shortcuts"))

        registry.apply(permission: .granted)
        XCTAssertEqual(registrar.registerCalls.count, 14)
        XCTAssertEqual(registry.runningFeatureIDs, ["shortcuts"])

        registrar.calls.removeAll()
        registry.apply(permission: .denied)
        XCTAssertEqual(registrar.calls, [.unregisterAll])
        XCTAssertEqual(registry.runningFeatureIDs, [])
    }

    func testRegistrationFailureDoesNotThrow() {
        registrar.failsAll = true
        let feature = ShortcutsFeature(engine: engine)

        XCTAssertNoThrow(try feature.start())
        XCTAssertEqual(engine.registrationFailures.count, 14)
    }
}
