import XCTest
import WindowCore

final class SettingsFormLayoutTests: XCTestCase {
    func testSections() {
        XCTAssertEqual(SettingsFormLayout.sections, [.shortcuts, .mouse, .excludedApps, .general])
        XCTAssertEqual(SettingsFormLayout.sections.map(\.title),
                       ["키보드 배치 단축키", "마우스로 창 다루기", "이 앱에서는 끄기", nil])
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
        XCTAssertEqual(SettingsFormLayout.mouseRows.map(\.title), ["이동", "크기조정"])
        XCTAssertEqual(SettingsFormLayout.bringWindowToFrontTitle, "창을 잡을 때 그 앱을 앞으로 가져오기")
    }

    func testActionTitles() {
        let expected: [WindowAction: String] = [
            .topLeft: "좌상단", .top: "상단", .topRight: "우상단",
            .left: "좌측", .center: "가운데", .right: "우측",
            .bottomLeft: "좌하단", .bottom: "하단", .bottomRight: "우하단",
            .fill: "전체화면 채우기", .previousDisplay: "왼쪽 모니터로", .nextDisplay: "오른쪽 모니터로",
            .undo: "되돌리기", .redo: "다시하기",
        ]
        for action in WindowAction.allCases {
            XCTAssertEqual(SettingsFormLayout.title(for: action), expected[action], action.rawValue)
        }
    }

    // ⌥ 단독·⌥⇧ 조합은 특수문자 입력을 가로챌 수 있다는 안내
    func testOptionOnlyAdvisory() {
        let message = "⌥만(또는 ⌥⇧) 쓰는 조합은 다른 앱의 특수문자 입력을 가로챌 수 있습니다"
        XCTAssertEqual(SettingsFormLayout.advisory(for: KeyCombo(keyCode: 0x25, modifiers: [.option])), message)
        XCTAssertEqual(SettingsFormLayout.advisory(for: KeyCombo(keyCode: 0x25, modifiers: [.option, .shift])), message)
        XCTAssertNil(SettingsFormLayout.advisory(for: KeyCombo(keyCode: 0x25, modifiers: [.option, .command])))
        XCTAssertNil(SettingsFormLayout.advisory(for: KeyCombo(keyCode: 0x25, modifiers: [.control])))
    }

    func testMouseErrorMessages() {
        XCTAssertEqual(SettingsFormLayout.message(for: .emptyMoveModifiers), "수정자를 하나 이상 선택해야 합니다")
        XCTAssertEqual(SettingsFormLayout.message(for: .emptyResizeModifiers), "수정자를 하나 이상 선택해야 합니다")
        XCTAssertEqual(SettingsFormLayout.message(for: .identicalModifiers), "이동과 크기조정은 서로 다른 조합이어야 합니다")
    }
}
