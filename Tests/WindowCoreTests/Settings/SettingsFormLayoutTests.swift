import XCTest
import WindowCore

final class SettingsFormLayoutTests: XCTestCase {
    func testSections() {
        XCTAssertEqual(SettingsFormLayout.sections, [.shortcuts, .mouse, .excludedApps, .general])
        XCTAssertEqual(SettingsFormLayout.sections.map(\.title),
                       ["Keyboard Shortcuts", "Move & Resize with Mouse", "Excluded Apps", nil])
    }

    func testShortcutGrid() {
        XCTAssertEqual(SettingsFormLayout.shortcutGrid, [
            [.topLeft, .top], [.topRight, .left], [.center, .right], [.bottomLeft, .bottom],
            [.bottomRight, .fill], [.previousDisplay, .nextDisplay], [.undo, .redo],
        ])
        XCTAssertTrue(SettingsFormLayout.shortcutGrid.allSatisfy { $0.count == 2 })
        XCTAssertEqual(SettingsFormLayout.shortcutGrid.flatMap { $0 }, WindowAction.allCases)
    }

    func testMouseModifierOrder() {
        XCTAssertEqual(SettingsFormLayout.mouseModifierOrder, [.shift, .fn, .control, .option, .command])
        XCTAssertEqual(SettingsFormLayout.mouseModifierOrder.map(SettingsFormLayout.label(for:)),
                       ["Shift", "Fn", "Control", "Option", "Command"])
        XCTAssertEqual(SettingsFormLayout.mouseRows.map(\.target), [.move, .resize])
        XCTAssertEqual(SettingsFormLayout.mouseRows.map(\.title), ["Move", "Resize"])
        XCTAssertEqual(SettingsFormLayout.bringWindowToFrontTitle, "Bring the app to the front when grabbing its window")
    }

    func testActionTitles() {
        let expected: [WindowAction: String] = [
            .topLeft: "Top Left", .top: "Top", .topRight: "Top Right",
            .left: "Left", .center: "Center", .right: "Right",
            .bottomLeft: "Bottom Left", .bottom: "Bottom", .bottomRight: "Bottom Right",
            .fill: "Fill Screen", .previousDisplay: "Previous Display", .nextDisplay: "Next Display",
            .undo: "Undo", .redo: "Redo",
        ]
        for action in WindowAction.allCases {
            XCTAssertEqual(SettingsFormLayout.title(for: action), expected[action], action.rawValue)
        }
    }

    // ⌥ 단독·⌥⇧ 조합은 특수문자 입력을 가로챌 수 있다는 안내
    func testOptionOnlyAdvisory() {
        let message = "Shortcuts with only ⌥ (or ⌥⇧) can block typing special characters in other apps"
        XCTAssertEqual(SettingsFormLayout.advisory(for: KeyCombo(keyCode: 0x25, modifiers: [.option])), message)
        XCTAssertEqual(SettingsFormLayout.advisory(for: KeyCombo(keyCode: 0x25, modifiers: [.option, .shift])), message)
        XCTAssertNil(SettingsFormLayout.advisory(for: KeyCombo(keyCode: 0x25, modifiers: [.option, .command])))
        XCTAssertNil(SettingsFormLayout.advisory(for: KeyCombo(keyCode: 0x25, modifiers: [.control])))
    }

    func testMouseErrorMessages() {
        XCTAssertEqual(SettingsFormLayout.message(for: .emptyMoveModifiers), "Select at least one modifier")
        XCTAssertEqual(SettingsFormLayout.message(for: .emptyResizeModifiers), "Select at least one modifier")
        XCTAssertEqual(SettingsFormLayout.message(for: .identicalModifiers), "Move and Resize need different modifier combinations")
    }
}
