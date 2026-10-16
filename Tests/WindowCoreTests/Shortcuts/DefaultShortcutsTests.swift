import XCTest
import WindowCore

final class DefaultShortcutsTests: XCTestCase {
    func testDefaultsCoverAllActions() {
        XCTAssertEqual(WindowAction.allCases.count, 14)
        for action in WindowAction.allCases {
            XCTAssertNotNil(DefaultShortcuts.bindings[action], "\(action) 기본값 없음")
        }

        let expected: [(WindowAction, UInt32)] = [
            (.topLeft, 0x10), (.top, 0x20), (.topRight, 0x22),
            (.left, 0x04), (.center, 0x26), (.right, 0x28),
            (.bottomLeft, 0x0B), (.bottom, 0x2D), (.bottomRight, 0x2E),
            (.fill, 0x03), (.previousDisplay, 0x2B), (.nextDisplay, 0x2F),
        ]
        for (action, keyCode) in expected {
            XCTAssertEqual(DefaultShortcuts.bindings[action], KeyCombo(keyCode: keyCode, modifiers: [.shift, .option, .command]), "\(action)")
        }
    }

    func testUndoRedoDefaults() {
        XCTAssertEqual(DefaultShortcuts.bindings[.undo], KeyCombo(keyCode: 0x06, modifiers: [.option, .command]))
        XCTAssertEqual(DefaultShortcuts.bindings[.redo], KeyCombo(keyCode: 0x06, modifiers: [.shift, .option, .command]))
    }

    func testHotKeyIDMapping() {
        XCTAssertEqual(WindowAction.left.hotKeyID, 4)
        XCTAssertEqual(WindowAction.center.hotKeyID, 5)
        XCTAssertEqual(WindowAction.undo.hotKeyID, 13)
        XCTAssertEqual(WindowAction.redo.hotKeyID, 14)
        for action in WindowAction.allCases {
            XCTAssertEqual(WindowAction(hotKeyID: action.hotKeyID), action)
        }
        XCTAssertNil(WindowAction(hotKeyID: 0))
        XCTAssertNil(WindowAction(hotKeyID: 15))
    }
}
