import XCTest
import WindowCore

final class MouseModifierMatcherTests: XCTestCase {
    private let settings = MouseDragSettings.default

    func testCGEventFlagsMask() {
        XCTAssertEqual(MouseModifierSet.shift.cgEventFlagsMask, 0x20000)
        XCTAssertEqual(MouseModifierSet.fn.cgEventFlagsMask, 0x800000)
        XCTAssertEqual(MouseModifierSet.control.cgEventFlagsMask, 0x40000)
        XCTAssertEqual(MouseModifierSet.option.cgEventFlagsMask, 0x80000)
        XCTAssertEqual(MouseModifierSet.command.cgEventFlagsMask, 0x100000)
        XCTAssertEqual(([.fn, .control] as MouseModifierSet).cgEventFlagsMask, 0x840000)
        XCTAssertEqual(MouseModifierSet.capsLockFlag, 0x10000)
        XCTAssertEqual(MouseModifierSet.shift.rawValue, 1)
        XCTAssertEqual(MouseModifierSet.fn.rawValue, 2)
        XCTAssertEqual(MouseModifierSet.control.rawValue, 4)
        XCTAssertEqual(MouseModifierSet.option.rawValue, 8)
        XCTAssertEqual(MouseModifierSet.command.rawValue, 16)
    }

    func testEventMaskIsMouseMovedAndFlagsChangedOnly() {
        XCTAssertEqual(MouseDragEventMask.value, 0x1020)
        XCTAssertEqual(MouseDragEventMask.value, (1 << 5) | (1 << 12))
        for bit in [1, 2, 3, 4, 6, 7, 10, 11, 22] {
            XCTAssertEqual(MouseDragEventMask.value & (UInt64(1) << UInt64(bit)), 0, "bit \(bit)")
        }
    }

    func testMouseActionChangeSource() {
        XCTAssertEqual(MouseAction.move.changeSource, .mouseMove)
        XCTAssertEqual(MouseAction.resize.changeSource, .mouseResize)
    }

    func testExactMoveMatch() {
        XCTAssertEqual(MouseModifierMatcher.action(for: 0x840000, settings: settings), .move)
    }

    func testExactResizeMatch() {
        XCTAssertEqual(MouseModifierMatcher.action(for: 0x880000, settings: settings), .resize)
    }

    func testExtraModifierRejects() {
        for flags: UInt64 in [0x840000 | 0x20000, 0x840000 | 0x100000, 0x840000 | 0x80000] {
            XCTAssertNil(MouseModifierMatcher.action(for: flags, settings: settings), "flags \(flags)")
        }
    }

    func testMissingModifierRejects() {
        for flags: UInt64 in [0x40000, 0x800000, 0] {
            XCTAssertNil(MouseModifierMatcher.action(for: flags, settings: settings), "flags \(flags)")
        }
    }

    func testCapsLockDisables() {
        XCTAssertNil(MouseModifierMatcher.action(for: 0x840000 | 0x10000, settings: settings))
        XCTAssertNil(MouseModifierMatcher.action(for: 0x880000 | 0x10000, settings: settings))
    }

    func testIrrelevantFlagsIgnored() {
        XCTAssertEqual(MouseModifierMatcher.action(for: 0x840000 | 0x100 | 0x200000, settings: settings), .move)
    }

    func testMovePriorityWhenBothMatch() {
        let same = MouseDragSettings(moveModifiers: [.control], resizeModifiers: [.control], bringWindowToFront: true)
        XCTAssertEqual(MouseModifierMatcher.action(for: 0x40000, settings: same), .move)
    }

    /// 수정자 0개 설정은 아무 키도 안 눌린 상태와 일치하면 안 된다.
    func testEmptyModifiersNeverMatch() {
        let empty = MouseDragSettings(moveModifiers: [], resizeModifiers: [], bringWindowToFront: true)
        XCTAssertNil(MouseModifierMatcher.action(for: 0, settings: empty))
    }
}
