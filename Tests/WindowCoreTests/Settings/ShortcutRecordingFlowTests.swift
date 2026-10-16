import XCTest
import WindowCore

/// 녹화 확정 → `ShortcutEngine` 겹침·등록 실패·녹화 사유 연동.
final class ShortcutRecordingFlowTests: XCTestCase {
    private var suite: SettingsTestDefaults!
    private var registrar: SettingsFakeRegistrar!

    private let hyper: ModifierSet = [.shift, .option, .command]

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

    private func commit(_ keyCode: UInt16, _ modifiers: RecordingModifiers) -> KeyCombo {
        guard case let .commit(combo) = ShortcutRecordingInterpreter.interpret(keyCode: keyCode, modifiers: modifiers) else {
            XCTFail("commit 아님")
            return KeyCombo(keyCode: 0, modifiers: [])
        }
        return combo
    }

    func testConflictKeepsBindings() {
        let engine = suite.makeEngine(registrar: registrar)
        engine.start()
        let registersBefore = registrar.registerCount

        let combo = commit(0x10, [.shift, .option, .command])  // ⌥⇧⌘Y = topLeft 기본값
        XCTAssertEqual(engine.setShortcut(combo, for: .top), .conflict([.topLeft]))
        XCTAssertEqual(engine.bindings[.top], KeyCombo(keyCode: 0x20, modifiers: hyper))
        XCTAssertEqual(registrar.registerCount, registersBefore)
    }

    func testSameComboSameAction() {
        let engine = suite.makeEngine(registrar: registrar)
        engine.start()
        XCTAssertEqual(engine.setShortcut(commit(0x10, [.shift, .option, .command]), for: .topLeft), .applied)
    }

    func testRegistrationFailureSurfaced() {
        registrar.failingCombos = [KeyCombo(keyCode: 0x04, modifiers: hyper), KeyCombo(keyCode: 0x20, modifiers: hyper)]
        let engine = suite.makeEngine(registrar: registrar)
        engine.start()
        XCTAssertEqual(engine.registrationFailures, [.left, .top])
        XCTAssertEqual(SettingsFormLayout.warningActions(registrationFailures: engine.registrationFailures), [.top, .left])
    }

    func testRecordingEndWhilePaused() {
        let engine = suite.makeEngine(registrar: registrar)
        engine.start()
        let policy = ActivationPolicy(isPaused: true)
        SettingsActivationSync.syncSuspendReasons(engine: engine, policy: policy, frontmostBundleID: nil)
        let registersAfterPause = registrar.registerCount

        engine.suspend(.recording)
        engine.resume(.recording)

        XCTAssertEqual(engine.suspendReasons, [.userPaused])
        XCTAssertTrue(engine.isSuspended)
        XCTAssertEqual(registrar.registerCount, registersAfterPause)
    }

    func testRecordingEndResumes() {
        let engine = suite.makeEngine(registrar: registrar)
        engine.start()
        engine.suspend(.recording)
        registrar.calls = []

        engine.resume(.recording)

        XCTAssertTrue(engine.suspendReasons.isEmpty)
        XCTAssertEqual(registrar.registerCount, WindowAction.allCases.count)
    }
}
