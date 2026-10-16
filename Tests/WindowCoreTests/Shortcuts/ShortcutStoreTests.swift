import XCTest
import WindowCore

final class ShortcutStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    private let ctrlOptCmdL = KeyCombo(keyCode: 0x25, modifiers: [.control, .option, .command])

    override func setUp() {
        super.setUp()
        suiteName = "WindowCoreTests.Shortcuts.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    private func storedJSON() throws -> [String: Any] {
        let data = try XCTUnwrap(defaults.data(forKey: ShortcutStore.key))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func writeRaw(_ json: String) {
        defaults.set(Data(json.utf8), forKey: ShortcutStore.key)
    }

    func testLoadWithoutStoredDataReturnsDefaults() {
        let store = ShortcutStore(defaults: defaults)
        XCTAssertEqual(store.load(), DefaultShortcuts.bindings)
        XCTAssertEqual(store.lastLoadIssues, [])
    }

    func testSaveThenLoadRoundTrip() throws {
        var bindings = DefaultShortcuts.bindings
        bindings[.left] = ctrlOptCmdL
        ShortcutStore(defaults: defaults).save(bindings)

        let loaded = ShortcutStore(defaults: defaults).load()
        XCTAssertEqual(loaded[.left], ctrlOptCmdL)
        for action in WindowAction.allCases where action != .left {
            XCTAssertEqual(loaded[action], DefaultShortcuts.bindings[action], "\(action)")
        }
        XCTAssertEqual(ShortcutStore.key, "shortcuts.v1")
        XCTAssertEqual(try storedJSON()["version"] as? Int, 1)
    }

    func testClearedShortcutStaysCleared() throws {
        var bindings = DefaultShortcuts.bindings
        bindings[.center] = nil
        ShortcutStore(defaults: defaults).save(bindings)

        XCTAssertNil(ShortcutStore(defaults: defaults).load()[.center])
        let stored = try XCTUnwrap(try storedJSON()["bindings"] as? [String: Any])
        XCTAssertTrue(stored["center"] is NSNull)
    }

    func testRestoreDefaultsOverwritesStored() {
        var bindings = DefaultShortcuts.bindings
        bindings[.left] = ctrlOptCmdL
        bindings[.top] = KeyCombo(keyCode: 0x23, modifiers: [.control, .option, .command])
        bindings[.center] = nil
        let store = ShortcutStore(defaults: defaults)
        store.save(bindings)

        store.restoreDefaults()

        XCTAssertNotNil(defaults.object(forKey: ShortcutStore.key))
        XCTAssertEqual(ShortcutStore(defaults: defaults).load(), DefaultShortcuts.bindings)
    }

    func testCorruptDataFallsBackToDefaults() {
        writeRaw("not json")
        let store = ShortcutStore(defaults: defaults)
        XCTAssertEqual(store.load(), DefaultShortcuts.bindings)
        XCTAssertEqual(store.lastLoadIssues, [.corruptData])

        writeRaw(#"{"version":2,"bindings":{}}"#)
        let store2 = ShortcutStore(defaults: defaults)
        XCTAssertEqual(store2.load(), DefaultShortcuts.bindings)
        XCTAssertEqual(store2.lastLoadIssues, [.corruptData])

        defaults.set("broken", forKey: ShortcutStore.key)
        let store3 = ShortcutStore(defaults: defaults)
        XCTAssertEqual(store3.load(), DefaultShortcuts.bindings)
        XCTAssertEqual(store3.lastLoadIssues, [.corruptData])
    }

    func testUnknownAndMissingKeys() {
        writeRaw(#"{"version":1,"bindings":{"foo":{"keyCode":1,"modifiers":["command"]},"left":{"keyCode":37,"modifiers":["control","option","command"]}}}"#)
        let store = ShortcutStore(defaults: defaults)
        let loaded = store.load()

        XCTAssertEqual(loaded[.left], ctrlOptCmdL)
        for action in WindowAction.allCases where action != .left {
            XCTAssertEqual(loaded[action], DefaultShortcuts.bindings[action], "\(action)")
        }
        XCTAssertEqual(store.lastLoadIssues, [])
    }

    func testInvalidAndDuplicateStoredValuesSanitized() {
        writeRaw(#"{"version":1,"bindings":{"left":{"keyCode":4,"modifiers":[]},"top":{"keyCode":7,"modifiers":["control","option","command"]},"bottom":{"keyCode":7,"modifiers":["command","option","control"]}}}"#)
        let store = ShortcutStore(defaults: defaults)
        let loaded = store.load()
        let x = KeyCombo(keyCode: 0x07, modifiers: [.control, .option, .command])

        XCTAssertEqual(loaded[.left], DefaultShortcuts.bindings[.left])
        XCTAssertEqual(loaded[.top], x)
        XCTAssertNil(loaded[.bottom])
        XCTAssertTrue(store.lastLoadIssues.contains(.invalidModifiers(.left)))
        XCTAssertTrue(store.lastLoadIssues.contains(.duplicateCleared(.bottom)))
    }

    func testOutOfRangeKeyCodeAndReservedStoredValuesFallBack() {
        writeRaw(#"{"version":1,"bindings":{"left":{"keyCode":4096,"modifiers":["control","option","command"]},"top":{"keyCode":8,"modifiers":["command"]},"right":{"keyCode":35,"modifiers":["control","option","command"]}}}"#)
        let store = ShortcutStore(defaults: defaults)
        let loaded = store.load()

        XCTAssertEqual(loaded[.left], DefaultShortcuts.bindings[.left])
        XCTAssertEqual(loaded[.top], DefaultShortcuts.bindings[.top])
        XCTAssertEqual(loaded[.right], KeyCombo(keyCode: 0x23, modifiers: [.control, .option, .command]))
        XCTAssertEqual(store.lastLoadIssues, [.invalidModifiers(.top), .invalidModifiers(.left)])
    }

    func testUnknownModifierStringFallsBackPerAction() throws {
        writeRaw(#"{"version":1,"bindings":{"left":{"keyCode":37,"modifiers":["fn","command"]},"top":{"keyCode":35,"modifiers":["control","option","command"]}}}"#)
        let store = ShortcutStore(defaults: defaults)
        let loaded = store.load()

        XCTAssertEqual(loaded[.left], DefaultShortcuts.bindings[.left])
        XCTAssertEqual(loaded[.top], KeyCombo(keyCode: 0x23, modifiers: [.control, .option, .command]))
        XCTAssertEqual(store.lastLoadIssues, [.invalidModifiers(.left)])

        store.save(loaded)
        XCTAssertNotNil(try storedJSON()["bindings"] as? [String: Any])
    }
}
