import XCTest
import WindowCore

final class ShortcutValidatorTests: XCTestCase {
    private let hyperH = KeyCombo(keyCode: 0x04, modifiers: [.shift, .option, .command])

    func testNoModifierIsInvalid() {
        XCTAssertFalse(ShortcutValidator.validate(KeyCombo(keyCode: 0x04, modifiers: [])))
    }

    func testShiftOnlyInvalid() {
        XCTAssertFalse(ShortcutValidator.validate(KeyCombo(keyCode: 0x04, modifiers: [.shift])))
        // ⌘H는 시스템 필수 조합이라 수정자 규칙만 보도록 L(0x25)을 쓴다.
        let valid: [ModifierSet] = [[.control], [.option], [.command], [.shift, .option], [.shift, .command]]
        for modifiers in valid {
            XCTAssertTrue(ShortcutValidator.validate(KeyCombo(keyCode: 0x25, modifiers: modifiers)), "\(modifiers)")
        }
    }

    func testReservedSystemCombosRejected() throws {
        let reserved: [(UInt32, ModifierSet)] = [
            (0x0C, [.command]), (0x0D, [.command]), (0x08, [.command]), (0x09, [.command]),
            (0x07, [.command]), (0x06, [.command]), (0x00, [.command]), (0x01, [.command]),
            (0x30, [.command]), (0x31, [.command]), (0x31, [.control]), (0x04, [.command]),
            (0x2E, [.command]),
        ]
        for (keyCode, modifiers) in reserved {
            let combo = KeyCombo(keyCode: keyCode, modifiers: modifiers)
            XCTAssertTrue(ShortcutValidator.isReserved(combo), combo.displayString)
            XCTAssertFalse(ShortcutValidator.validate(combo), combo.displayString)
        }

        for action in WindowAction.allCases {
            let combo = try XCTUnwrap(DefaultShortcuts.bindings[action])
            XCTAssertTrue(ShortcutValidator.validate(combo), "\(action) 기본값이 막힘")
        }
        XCTAssertFalse(ShortcutValidator.isReserved(KeyCombo(keyCode: 0x06, modifiers: [.option, .command])))
        XCTAssertFalse(ShortcutValidator.isReserved(KeyCombo(keyCode: 0x06, modifiers: [.shift, .option, .command])))
    }

    func testKeyCodeRange() {
        XCTAssertTrue(ShortcutValidator.validate(KeyCombo(keyCode: 0x7F, modifiers: [.control, .option])))
        XCTAssertFalse(ShortcutValidator.validate(KeyCombo(keyCode: 0x80, modifiers: [.control, .option])))
        XCTAssertFalse(ShortcutValidator.validate(KeyCombo(keyCode: 0xFFFF, modifiers: [.control, .option])))
    }

    func testConflictWithOtherAction() {
        XCTAssertEqual(ShortcutValidator.conflicts(for: hyperH, action: .right, in: DefaultShortcuts.bindings), [.left])
    }

    func testSelfAndNilAreNotConflicts() {
        XCTAssertEqual(ShortcutValidator.conflicts(for: hyperH, action: .left, in: DefaultShortcuts.bindings), [])

        var cleared = DefaultShortcuts.bindings
        cleared[.left] = nil
        XCTAssertEqual(ShortcutValidator.conflicts(for: hyperH, action: .right, in: cleared), [])
    }

    func testDifferentModifiersNotConflict() throws {
        let defaults = DefaultShortcuts.bindings
        let undo = try XCTUnwrap(defaults[.undo])
        let redo = try XCTUnwrap(defaults[.redo])
        XCTAssertNotEqual(undo, redo)

        var total = 0
        for action in WindowAction.allCases {
            let combo = try XCTUnwrap(defaults[action])
            total += ShortcutValidator.conflicts(for: combo, action: action, in: defaults).count
        }
        XCTAssertEqual(total, 0)
    }

    func testConflictsSortedByDeclarationOrder() {
        let x = KeyCombo(keyCode: 0x07, modifiers: [.control, .option, .command])
        var bindings = DefaultShortcuts.bindings
        bindings[.bottom] = x
        bindings[.top] = x
        XCTAssertEqual(ShortcutValidator.conflicts(for: x, action: .left, in: bindings), [.top, .bottom])
    }
}
