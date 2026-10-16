import XCTest
import WindowCore

final class SettingsDefaultsRestorerTests: XCTestCase {
    private var suite: SettingsTestDefaults!

    override func setUp() {
        super.setUp()
        suite = SettingsTestDefaults()
    }

    override func tearDown() {
        suite.tearDown()
        suite = nil
        super.tearDown()
    }

    func testRestoreAll() throws {
        let registrar = SettingsFakeRegistrar()
        let engine = suite.makeEngine(registrar: registrar)
        engine.start()
        let mouseStore = MouseDragSettingsStore(defaults: suite.defaults)
        let generalStore = GeneralSettingsStore(defaults: suite.defaults)

        engine.setShortcut(nil, for: .left)
        try mouseStore.save(MouseDragSettings(moveModifiers: [.shift, .command], resizeModifiers: [.fn, .option], bringWindowToFront: false))
        generalStore.save(GeneralSettings(isPaused: true, excludedBundleIDs: ["com.a"]))
        let generalBytes = suite.defaults.data(forKey: GeneralSettingsStore.key)

        try SettingsDefaultsRestorer.restoreAll(engine: engine, mouseStore: mouseStore)

        XCTAssertEqual(engine.bindings[.left], KeyCombo(keyCode: 0x04, modifiers: [.shift, .option, .command]))
        XCTAssertEqual(engine.bindings[.undo], KeyCombo(keyCode: 0x06, modifiers: [.option, .command]))
        XCTAssertEqual(engine.bindings[.redo], KeyCombo(keyCode: 0x06, modifiers: [.shift, .option, .command]))
        XCTAssertEqual(mouseStore.load(), .default)
        XCTAssertEqual(mouseStore.load(), MouseDragSettings(moveModifiers: [.fn, .control], resizeModifiers: [.fn, .option], bringWindowToFront: true))
        XCTAssertNotNil(generalBytes)
        XCTAssertEqual(suite.defaults.data(forKey: GeneralSettingsStore.key), generalBytes)
    }
}
