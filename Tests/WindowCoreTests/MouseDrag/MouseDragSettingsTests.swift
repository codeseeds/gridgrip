import XCTest
import WindowCore

final class MouseDragSettingsTests: XCTestCase {
    private var suiteNames: [String] = []

    override func tearDown() {
        for name in suiteNames {
            UserDefaults().removePersistentDomain(forName: name)
        }
        suiteNames = []
        super.tearDown()
    }

    private func makeDefaults() -> UserDefaults {
        let name = "MouseDragTests-\(UUID().uuidString)"
        suiteNames.append(name)
        return UserDefaults(suiteName: name)!
    }

    func testLoadReturnsDefaultsWhenEmpty() {
        let loaded = MouseDragSettingsStore(defaults: makeDefaults()).load()
        XCTAssertEqual(loaded.moveModifiers, [.fn, .control])
        XCTAssertEqual(loaded.resizeModifiers, [.fn, .option])
        XCTAssertTrue(loaded.bringWindowToFront)
        XCTAssertEqual(loaded, MouseDragSettings.default)
    }

    func testSaveThenLoadRoundTrip() throws {
        let defaults = makeDefaults()
        let store = MouseDragSettingsStore(defaults: defaults)
        let settings = MouseDragSettings(moveModifiers: [.command, .shift], resizeModifiers: [.control], bringWindowToFront: false)
        try store.save(settings)
        XCTAssertEqual(store.load(), settings)
        XCTAssertEqual(defaults.integer(forKey: "mouse.moveModifiers"), 17)
        XCTAssertEqual(defaults.integer(forKey: "mouse.resizeModifiers"), 4)
        XCTAssertFalse(defaults.bool(forKey: "mouse.bringWindowToFront"))
    }

    func testStorageKeys() {
        XCTAssertEqual(MouseDragSettingsStore.moveModifiersKey, "mouse.moveModifiers")
        XCTAssertEqual(MouseDragSettingsStore.resizeModifiersKey, "mouse.resizeModifiers")
        XCTAssertEqual(MouseDragSettingsStore.bringWindowToFrontKey, "mouse.bringWindowToFront")
    }

    func testValidateRejectsEmptyMoveModifiers() {
        let settings = MouseDragSettings(moveModifiers: [], resizeModifiers: [.fn, .option], bringWindowToFront: true)
        XCTAssertTrue(settings.validate().contains(.emptyMoveModifiers))
    }

    func testValidateRejectsEmptyResizeModifiers() {
        let settings = MouseDragSettings(moveModifiers: [.fn, .control], resizeModifiers: [], bringWindowToFront: true)
        XCTAssertTrue(settings.validate().contains(.emptyResizeModifiers))
    }

    func testValidateRejectsIdenticalModifiers() {
        let settings = MouseDragSettings(moveModifiers: [.fn, .control], resizeModifiers: [.control, .fn], bringWindowToFront: true)
        XCTAssertTrue(settings.validate().contains(.identicalModifiers))
    }

    func testDefaultIsValid() {
        XCTAssertTrue(MouseDragSettings.default.validate().isEmpty)
    }

    func testSaveInvalidThrowsAndKeepsPrevious() throws {
        let defaults = makeDefaults()
        let store = MouseDragSettingsStore(defaults: defaults)
        let previous = MouseDragSettings(moveModifiers: [.command], resizeModifiers: [.shift], bringWindowToFront: true)
        try store.save(previous)

        let invalid = MouseDragSettings(moveModifiers: [], resizeModifiers: [.shift], bringWindowToFront: false)
        XCTAssertThrowsError(try store.save(invalid))
        XCTAssertEqual(store.load(), previous)
        XCTAssertEqual(defaults.integer(forKey: "mouse.moveModifiers"), 16)
    }

    func testLoadRepairsInvalidFieldsIndividually() {
        // (a) 이동 0
        let a = makeDefaults()
        a.set(0, forKey: "mouse.moveModifiers")
        a.set(4, forKey: "mouse.resizeModifiers")
        let loadedA = MouseDragSettingsStore(defaults: a).load()
        XCTAssertEqual(loadedA.moveModifiers, [.fn, .control])
        XCTAssertEqual(loadedA.resizeModifiers, [.control])

        // (b) 알 수 없는 비트만
        let b = makeDefaults()
        b.set(64, forKey: "mouse.resizeModifiers")
        b.set(16, forKey: "mouse.moveModifiers")
        let loadedB = MouseDragSettingsStore(defaults: b).load()
        XCTAssertEqual(loadedB.resizeModifiers, [.fn, .option])
        XCTAssertEqual(loadedB.moveModifiers, [.command])

        // (c) 타입 다름
        let c = makeDefaults()
        c.set("x", forKey: "mouse.moveModifiers")
        c.set(4, forKey: "mouse.resizeModifiers")
        let loadedC = MouseDragSettingsStore(defaults: c).load()
        XCTAssertEqual(loadedC.moveModifiers, [.fn, .control])
        XCTAssertEqual(loadedC.resizeModifiers, [.control])

        // (d)(e) Bool 자리에 문자열
        let d = makeDefaults()
        d.set("yes", forKey: "mouse.bringWindowToFront")
        let loadedD = MouseDragSettingsStore(defaults: d).load()
        XCTAssertTrue(loadedD.bringWindowToFront)

        let e = makeDefaults()
        e.set("abc", forKey: "mouse.bringWindowToFront")
        let loadedE = MouseDragSettingsStore(defaults: e).load()
        XCTAssertTrue(loadedE.bringWindowToFront)

        for loaded in [loadedA, loadedB, loadedC, loadedD, loadedE] {
            XCTAssertTrue(loaded.validate().isEmpty)
        }
    }

    func testLoadFallsBackToFullDefaultsWhenRepairedStillInvalid() {
        let cases: [(move: Int?, resize: Int?)] = [(10, 10), (10, nil), (6, 6), (0, 0)]
        for (move, resize) in cases {
            let defaults = makeDefaults()
            if let move { defaults.set(move, forKey: "mouse.moveModifiers") }
            if let resize { defaults.set(resize, forKey: "mouse.resizeModifiers") }
            let loaded = MouseDragSettingsStore(defaults: defaults).load()
            XCTAssertEqual(loaded, MouseDragSettings.default, "move \(String(describing: move)) resize \(String(describing: resize))")
            XCTAssertFalse(loaded.moveModifiers.isEmpty)
            XCTAssertFalse(loaded.resizeModifiers.isEmpty)
            XCTAssertNotEqual(loaded.moveModifiers, loaded.resizeModifiers)
        }
    }

    func testLoadDoesNotWrite() {
        let defaults = makeDefaults()
        defaults.set(0, forKey: "mouse.moveModifiers")
        _ = MouseDragSettingsStore(defaults: defaults).load()
        XCTAssertEqual(defaults.integer(forKey: "mouse.moveModifiers"), 0)
    }
}
