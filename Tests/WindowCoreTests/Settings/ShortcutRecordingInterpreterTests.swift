import XCTest
import WindowCore

final class ShortcutRecordingInterpreterTests: XCTestCase {
    private func interpret(_ keyCode: UInt16, _ modifiers: RecordingModifiers) -> RecordingIntent {
        ShortcutRecordingInterpreter.interpret(keyCode: keyCode, modifiers: modifiers)
    }

    func testCommitWithModifiers() {
        XCTAssertEqual(interpret(0x10, [.shift, .option, .command]),
                       .commit(KeyCombo(keyCode: 0x10, modifiers: [.shift, .option, .command])))
    }

    func testRejectNoModifier() {
        XCTAssertEqual(interpret(0x10, []), .rejectNoModifier)
    }

    func testRejectShiftOnly() {
        XCTAssertEqual(interpret(0x10, [.shift]), .rejectNoModifier)
    }

    func testEscape() {
        XCTAssertEqual(interpret(0x35, []), .cancel)
        XCTAssertEqual(interpret(0x35, [.control, .option]), .commit(KeyCombo(keyCode: 0x35, modifiers: [.control, .option])))
    }

    func testDeleteClears() {
        XCTAssertEqual(interpret(0x33, []), .clear)
        XCTAssertEqual(interpret(0x75, []), .clear)
    }

    func testModifierKeysIgnored() {
        for keyCode: UInt16 in [0x37, 0x36, 0x38, 0x3C, 0x3A, 0x3D, 0x3B, 0x3E, 0x3F, 0x39] {
            XCTAssertEqual(interpret(keyCode, [.command]), .ignore, String(format: "0x%02X", keyCode))
        }
    }

    func testFnCapsLockStripped() {
        XCTAssertEqual(interpret(0x7B, [.function, .control, .option]),
                       .commit(KeyCombo(keyCode: 0x7B, modifiers: [.control, .option])))
        XCTAssertEqual(interpret(0x10, [.capsLock]), .rejectNoModifier)
        XCTAssertEqual(interpret(0x10, [.function]), .rejectNoModifier)
    }

    // 시스템 필수 조합은 판정 함수가 거르지 않고 엔진 결과(.invalidModifiers)로 받는다.
    func testReservedComboIsCommittedForEngineToReject() {
        XCTAssertEqual(interpret(0x0D, [.command]), .commit(KeyCombo(keyCode: 0x0D, modifiers: [.command])))
    }
}
