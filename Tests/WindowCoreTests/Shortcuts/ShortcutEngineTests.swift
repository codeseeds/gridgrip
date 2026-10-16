import XCTest
import WindowCore

/// 테스트 공용 가짜 전역 단축키 등록기. 호출을 순서대로 기록하고, 지정한 조합·번호는 실패시킨다.
final class ShortcutsFakeRegistrar: HotKeyRegistering {
    enum Call: Equatable {
        case register(KeyCombo, id: UInt32)
        case unregister(id: UInt32)
        case unregisterAll
    }

    var onHotKey: ((UInt32) -> Void)?
    var calls: [Call] = []
    var failingCombos: Set<KeyCombo> = []
    var failsAll = false

    var registerCalls: [(combo: KeyCombo, id: UInt32)] {
        calls.compactMap { call in
            if case let .register(combo, id) = call { return (combo, id) }
            return nil
        }
    }

    var unregisterAllCount: Int {
        calls.filter { $0 == .unregisterAll }.count
    }

    func register(_ combo: KeyCombo, id: UInt32) -> Bool {
        calls.append(.register(combo, id: id))
        return !failsAll && !failingCombos.contains(combo)
    }

    func unregister(id: UInt32) {
        calls.append(.unregister(id: id))
    }

    func unregisterAll() {
        calls.append(.unregisterAll)
    }
}

final class ShortcutEngineTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var registrar: ShortcutsFakeRegistrar!
    private var dispatcher: ActionDispatcher!
    private var changeCount = 0
    private var events: [ShortcutEngineEvent] = []

    private let ctrlOptCmdL = KeyCombo(keyCode: 0x25, modifiers: [.control, .option, .command])
    private let ctrlOptCmdP = KeyCombo(keyCode: 0x23, modifiers: [.control, .option, .command])
    private let hyperH = KeyCombo(keyCode: 0x04, modifiers: [.shift, .option, .command])
    private let hyperF = KeyCombo(keyCode: 0x03, modifiers: [.shift, .option, .command])

    override func setUp() {
        super.setUp()
        suiteName = "WindowCoreTests.Shortcuts.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        registrar = ShortcutsFakeRegistrar()
        dispatcher = ActionDispatcher()
        changeCount = 0
        events = []
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        registrar = nil
        dispatcher = nil
        super.tearDown()
    }

    private func makeEngine() -> ShortcutEngine {
        let engine = ShortcutEngine(store: ShortcutStore(defaults: defaults), registrar: registrar, dispatcher: dispatcher)
        engine.onChange = { [unowned self] in changeCount += 1 }
        engine.onEvent = { [unowned self] in events.append($0) }
        return engine
    }

    private func loadStored() -> ShortcutBindings {
        ShortcutStore(defaults: defaults).load()
    }

    private func resetCounters() {
        registrar.calls.removeAll()
        changeCount = 0
        events.removeAll()
    }

    func testStartRegistersAllBindings() {
        let engine = makeEngine()
        XCTAssertEqual(registrar.calls, [])

        engine.start()

        XCTAssertEqual(registrar.calls.first, .unregisterAll)
        XCTAssertEqual(registrar.unregisterAllCount, 1)
        let registers = registrar.registerCalls
        XCTAssertEqual(registers.count, 14)
        XCTAssertEqual(Set(registers.map(\.id)), Set(1...14))
        XCTAssertEqual(registers.first { $0.id == 4 }?.combo, hyperH)

        resetCounters()
        engine.start()
        XCTAssertEqual(registrar.calls, [])
    }

    func testChangeReRegisters() {
        let engine = makeEngine()
        engine.start()
        resetCounters()

        XCTAssertEqual(engine.setShortcut(ctrlOptCmdL, for: .left), .applied)

        XCTAssertEqual(registrar.calls, [.unregister(id: 4), .register(ctrlOptCmdL, id: 4)])
        XCTAssertEqual(changeCount, 1)
        XCTAssertEqual(loadStored()[.left], ctrlOptCmdL)
    }

    func testConflictRejectedWithoutSideEffects() {
        let engine = makeEngine()
        engine.start()
        let before = engine.bindings
        resetCounters()

        XCTAssertEqual(engine.setShortcut(hyperH, for: .right), .conflict([.left]))

        XCTAssertEqual(engine.bindings, before)
        XCTAssertNil(defaults.object(forKey: ShortcutStore.key))
        XCTAssertEqual(registrar.calls, [])
        XCTAssertEqual(changeCount, 0)
    }

    func testReplacingConflicts() {
        let engine = makeEngine()
        engine.start()
        resetCounters()

        XCTAssertEqual(engine.setShortcut(hyperH, for: .right, replacingConflicts: true), .applied)

        XCTAssertNil(engine.shortcut(for: .left))
        XCTAssertEqual(engine.shortcut(for: .right), hyperH)
        XCTAssertEqual(registrar.calls, [.unregister(id: 4), .unregister(id: 6), .register(hyperH, id: 6)])
        let stored = loadStored()
        XCTAssertNil(stored[.left])
        XCTAssertEqual(stored[.right], hyperH)
        XCTAssertEqual(changeCount, 1)
    }

    func testInvalidModifiersRejected() {
        let engine = makeEngine()
        engine.start()
        let before = engine.bindings
        resetCounters()

        XCTAssertEqual(engine.setShortcut(KeyCombo(keyCode: 0x04, modifiers: [.shift]), for: .left), .invalidModifiers)

        XCTAssertEqual(engine.bindings, before)
        XCTAssertNil(defaults.object(forKey: ShortcutStore.key))
        XCTAssertEqual(registrar.calls, [])
        XCTAssertEqual(changeCount, 0)
    }

    func testReservedComboRejected() {
        let engine = makeEngine()
        engine.start()
        resetCounters()

        XCTAssertEqual(engine.setShortcut(KeyCombo(keyCode: 0x08, modifiers: [.command]), for: .left), .invalidModifiers)
        XCTAssertEqual(engine.shortcut(for: .left), hyperH)
        XCTAssertNil(defaults.object(forKey: ShortcutStore.key))
        XCTAssertEqual(registrar.calls, [])
        XCTAssertEqual(changeCount, 0)
    }

    func testClearUnregisters() {
        let engine = makeEngine()
        engine.start()
        resetCounters()

        XCTAssertEqual(engine.setShortcut(nil, for: .center), .applied)

        XCTAssertEqual(registrar.calls, [.unregister(id: 5)])
        XCTAssertNil(engine.shortcut(for: .center))
        XCTAssertNil(loadStored()[.center])
        XCTAssertEqual(changeCount, 1)
    }

    func testHotKeyDispatchesMappedAction() {
        var received: [WindowAction] = []
        dispatcher.setHandler(for: [.left, .undo]) { received.append($0) }
        let engine = makeEngine()
        engine.start()

        registrar.onHotKey?(4)
        XCTAssertEqual(received, [.left])
        XCTAssertEqual(events, [.hotKeyFired(.left, handled: true)])

        registrar.onHotKey?(13)
        XCTAssertEqual(received, [.left, .undo])
        XCTAssertEqual(events.last, .hotKeyFired(.undo, handled: true))

        registrar.onHotKey?(10)
        XCTAssertEqual(events.last, .hotKeyFired(.fill, handled: false))
    }

    func testSuspendResume() {
        let engine = makeEngine()
        engine.start()
        resetCounters()

        engine.suspend(.userPaused)
        XCTAssertEqual(registrar.calls, [.unregisterAll])
        XCTAssertTrue(engine.isSuspended)

        resetCounters()
        engine.suspend(.userPaused)
        XCTAssertEqual(registrar.calls, [])

        XCTAssertEqual(engine.setShortcut(ctrlOptCmdL, for: .left), .applied)
        XCTAssertEqual(loadStored()[.left], ctrlOptCmdL)
        XCTAssertEqual(registrar.calls, [])
        XCTAssertEqual(changeCount, 1)

        engine.resume(.userPaused)
        XCTAssertEqual(registrar.calls.first, .unregisterAll)
        XCTAssertEqual(registrar.registerCalls.count, 14)
        XCTAssertEqual(registrar.registerCalls.first { $0.id == 4 }?.combo, ctrlOptCmdL)
        XCTAssertFalse(engine.isSuspended)
    }

    func testRestoreDefaultsReRegisters() {
        let engine = makeEngine()
        engine.start()
        _ = engine.setShortcut(ctrlOptCmdL, for: .left)
        resetCounters()

        engine.restoreDefaults()

        XCTAssertEqual(registrar.calls.first, .unregisterAll)
        XCTAssertEqual(registrar.unregisterAllCount, 1)
        XCTAssertEqual(registrar.registerCalls.count, 14)
        XCTAssertEqual(registrar.registerCalls.first { $0.id == 4 }?.combo, hyperH)
        XCTAssertEqual(changeCount, 1)
        XCTAssertEqual(loadStored(), DefaultShortcuts.bindings)
        XCTAssertEqual(engine.bindings, DefaultShortcuts.bindings)
    }

    func testStopUnregistersAll() {
        var handled = 0
        dispatcher.setHandler(for: [.left]) { _ in handled += 1 }
        let engine = makeEngine()
        engine.start()
        resetCounters()

        engine.stop()
        XCTAssertEqual(registrar.calls, [.unregisterAll])
        XCTAssertFalse(engine.isStarted)

        resetCounters()
        engine.stop()
        XCTAssertEqual(registrar.calls, [])

        registrar.onHotKey?(4)
        XCTAssertEqual(handled, 0)
    }

    func testOverlappingSuspendReasons() {
        let engine = makeEngine()
        engine.start()
        resetCounters()

        engine.suspend(.userPaused)
        engine.suspend(.recording)
        engine.resume(.recording)
        XCTAssertEqual(registrar.registerCalls.count, 0)
        XCTAssertEqual(engine.suspendReasons, [.userPaused])

        engine.resume(.userPaused)
        XCTAssertEqual(registrar.registerCalls.count, 14)
    }

    func testSuspendBeforeStart() {
        let engine = makeEngine()
        engine.suspend(.userPaused)
        XCTAssertEqual(registrar.calls, [])

        engine.start()
        XCTAssertEqual(registrar.registerCalls.count, 0)
        XCTAssertTrue(engine.isStarted)

        engine.resume(.userPaused)
        XCTAssertEqual(registrar.registerCalls.count, 14)
    }

    func testChangesWhileStoppedSaveOnly() {
        let engine = makeEngine()
        XCTAssertEqual(engine.setShortcut(ctrlOptCmdL, for: .left), .applied)
        XCTAssertEqual(registrar.calls, [])
        XCTAssertEqual(loadStored()[.left], ctrlOptCmdL)

        engine.start()
        XCTAssertEqual(registrar.registerCalls.first { $0.id == 4 }?.combo, ctrlOptCmdL)

        engine.suspend(.excludedAppFrontmost)
        engine.stop()
        resetCounters()
        engine.start()
        XCTAssertEqual(registrar.registerCalls.count, 0)
        XCTAssertEqual(engine.suspendReasons, [.excludedAppFrontmost])
    }

    func testNilBindingSkippedOnFullRegister() {
        var stored = DefaultShortcuts.bindings
        stored[.center] = nil
        ShortcutStore(defaults: defaults).save(stored)
        let engine = makeEngine()

        engine.start()
        XCTAssertEqual(registrar.registerCalls.count, 13)
        XCTAssertFalse(registrar.registerCalls.contains { $0.id == 5 })

        resetCounters()
        engine.suspend(.recording)
        engine.resume(.recording)
        XCTAssertEqual(registrar.registerCalls.count, 13)
        XCTAssertFalse(registrar.registerCalls.contains { $0.id == 5 })
    }

    func testSettingSameComboIsNoOp() {
        let engine = makeEngine()
        engine.start()
        resetCounters()

        XCTAssertEqual(engine.setShortcut(hyperH, for: .left), .applied)
        XCTAssertEqual(registrar.calls, [])
        XCTAssertEqual(changeCount, 0)
    }

    func testRegistrarCallbackDoesNotRetainEngine() {
        var handled = 0
        dispatcher.setHandler(for: [.left]) { _ in handled += 1 }
        var engine: ShortcutEngine? = ShortcutEngine(store: ShortcutStore(defaults: defaults), registrar: registrar, dispatcher: dispatcher)
        weak var weakEngine: ShortcutEngine?
        weakEngine = engine
        XCTAssertNotNil(registrar.onHotKey)

        engine?.start()
        engine = nil

        XCTAssertNil(weakEngine)
        registrar.onHotKey?(4)
        XCTAssertEqual(handled, 0)
    }

    func testPartialRegistrationFailure() {
        registrar.failingCombos = [hyperF]
        let engine = makeEngine()

        engine.start()

        XCTAssertEqual(registrar.registerCalls.count, 14)
        XCTAssertEqual(engine.registrationFailures, [.fill])
        XCTAssertEqual(changeCount, 1)
        XCTAssertEqual(events, [.registrationFailed(.fill, hyperF)])
    }

    func testUnknownHotKeyIdIgnored() {
        var handled = 0
        dispatcher.setHandler(for: WindowAction.allCases) { _ in handled += 1 }
        let engine = makeEngine()
        engine.start()
        events.removeAll()

        registrar.onHotKey?(0)
        registrar.onHotKey?(99)

        XCTAssertEqual(handled, 0)
        XCTAssertEqual(events, [])
        _ = engine
    }

    func testSetShortcutRegistrationFailure() {
        let engine = makeEngine()
        engine.start()
        registrar.failingCombos = [ctrlOptCmdL]
        resetCounters()

        XCTAssertEqual(engine.setShortcut(ctrlOptCmdL, for: .left), .applied)

        XCTAssertEqual(loadStored()[.left], ctrlOptCmdL)
        XCTAssertEqual(engine.registrationFailures, [.left])
        XCTAssertEqual(changeCount, 1)
        XCTAssertEqual(events, [.registrationFailed(.left, ctrlOptCmdL)])
    }

    func testFailureClearedOnLaterSuccess() {
        let engine = makeEngine()
        engine.start()
        registrar.failingCombos = [ctrlOptCmdL]
        _ = engine.setShortcut(ctrlOptCmdL, for: .left)
        registrar.failingCombos = []
        resetCounters()

        XCTAssertEqual(engine.setShortcut(ctrlOptCmdP, for: .left), .applied)

        XCTAssertEqual(engine.registrationFailures, [])
        XCTAssertEqual(changeCount, 1)
    }

    func testFailureClearedOnClearStopSuspend() {
        registrar.failingCombos = [hyperF]
        let engine = makeEngine()
        engine.start()
        XCTAssertEqual(engine.registrationFailures, [.fill])

        // (a) 지우기
        _ = engine.setShortcut(nil, for: .fill)
        XCTAssertEqual(engine.registrationFailures, [])

        // (b) 정지
        _ = engine.setShortcut(hyperF, for: .fill)
        XCTAssertEqual(engine.registrationFailures, [.fill])
        changeCount = 0
        engine.stop()
        XCTAssertEqual(engine.registrationFailures, [])
        XCTAssertEqual(changeCount, 1)

        // (c) 일시정지
        engine.start()
        XCTAssertEqual(engine.registrationFailures, [.fill])
        engine.suspend(.userPaused)
        XCTAssertEqual(engine.registrationFailures, [])
    }

    func testHotKeyIgnoredWhenInactive() {
        var handled = 0
        dispatcher.setHandler(for: [.left]) { _ in handled += 1 }
        let engine = makeEngine()

        registrar.onHotKey?(4)
        XCTAssertEqual(handled, 0)

        engine.start()
        engine.suspend(.recording)
        registrar.onHotKey?(4)
        XCTAssertEqual(handled, 0)
        XCTAssertEqual(events, [])
    }

    func testRestoreDefaultsWhenAlreadyDefault() {
        registrar.failingCombos = [hyperF]
        let engine = makeEngine()
        engine.start()
        XCTAssertEqual(engine.registrationFailures, [.fill])
        registrar.failingCombos = []
        resetCounters()

        engine.restoreDefaults()

        XCTAssertEqual(registrar.unregisterAllCount, 1)
        XCTAssertEqual(registrar.registerCalls.count, 14)
        XCTAssertEqual(engine.registrationFailures, [])
        XCTAssertEqual(changeCount, 1)
        XCTAssertNotNil(defaults.object(forKey: ShortcutStore.key))

        resetCounters()
        engine.restoreDefaults()
        XCTAssertEqual(registrar.registerCalls.count, 14)
        XCTAssertEqual(changeCount, 0)
    }

    func testRestoreDefaultsWhileInactiveSavesOnly() {
        let engine = makeEngine()
        _ = engine.setShortcut(ctrlOptCmdL, for: .left)
        changeCount = 0

        engine.restoreDefaults()
        XCTAssertEqual(registrar.calls, [])
        XCTAssertEqual(loadStored(), DefaultShortcuts.bindings)
        XCTAssertEqual(changeCount, 1)

        engine.start()
        engine.suspend(.recording)
        _ = engine.setShortcut(ctrlOptCmdL, for: .left)
        resetCounters()
        engine.restoreDefaults()
        XCTAssertEqual(registrar.calls, [])
        XCTAssertEqual(changeCount, 1)

        engine.resume(.recording)
        XCTAssertEqual(registrar.registerCalls.count, 14)
        XCTAssertEqual(registrar.registerCalls.first { $0.id == 4 }?.combo, hyperH)
    }

    func testEngineExposesLoadIssues() {
        XCTAssertEqual(makeEngine().loadIssues, [])

        defaults.set(Data("not json".utf8), forKey: ShortcutStore.key)
        XCTAssertEqual(makeEngine().loadIssues, [.corruptData])
    }
}
