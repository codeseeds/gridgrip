import XCTest
import WindowCore

final class MenuModelTests: XCTestCase {
    func testComposeOrdersSectionsAndSeparators() {
        let first: [MenuEntry<String>] = MenuLayout.compose([
            .app: ["quit"], .permission: ["warn", "open"], .history: [],
        ])
        XCTAssertEqual(first, [.item("warn"), .item("open"), .separator, .item("quit")])

        let second: [MenuEntry<String>] = MenuLayout.compose([
            .app: ["quit"], .arrange: ["a"], .control: ["c"],
        ])
        XCTAssertEqual(second, [.item("a"), .separator, .item("c"), .separator, .item("quit")])

        let empty: [MenuEntry<String>] = MenuLayout.compose([:])
        XCTAssertEqual(empty, [])
    }

    func testSectionSlotRawValues() {
        XCTAssertEqual(MenuSectionSlot.allCases.map(\.rawValue), [0, 10, 20, 30, 40, 100])
        XCTAssertEqual(MenuSectionSlot.allCases, [.permission, .arrange, .history, .control, .preferences, .app])
        XCTAssertLessThan(MenuSectionSlot.arrange, MenuSectionSlot.history)
    }

    func testDeniedMenu() {
        let entries = MenuLayout.compose([
            .permission: BaseMenuSpec.permissionSection(.denied),
            .app: BaseMenuSpec.appSection(),
        ])
        XCTAssertEqual(entries.count, 4)
        guard entries.count == 4,
              case let .item(warning) = entries[0],
              case let .item(open) = entries[1],
              case .separator = entries[2],
              case let .item(quit) = entries[3]
        else { return XCTFail("메뉴 구성 불일치: \(entries)") }
        XCTAssertEqual(warning.title, "⚠︎ 손쉬운 사용 권한이 필요합니다")
        XCTAssertFalse(warning.isEnabled)
        XCTAssertEqual(open.title, "시스템 설정 열기…")
        XCTAssertTrue(open.isEnabled)
        XCTAssertEqual(quit.title, "GridGrip 종료")
    }

    func testGrantedMenu() {
        XCTAssertEqual(BaseMenuSpec.permissionSection(.granted), [])
        let entries = MenuLayout.compose([
            .permission: BaseMenuSpec.permissionSection(.granted),
            .app: BaseMenuSpec.appSection(),
        ])
        XCTAssertEqual(entries.count, 1)
        guard case let .item(quit)? = entries.first else { return XCTFail("종료 항목 없음") }
        XCTAssertEqual(quit.title, "GridGrip 종료")
        XCTAssertFalse(entries.contains(.separator))
    }

    func testQuitItemShortcut() throws {
        let quit = try XCTUnwrap(BaseMenuSpec.appSection().first { $0.id == "app.quit" })
        XCTAssertEqual(quit.keyEquivalent, "q")
        XCTAssertEqual(quit.modifiers, [.command])
    }
}
