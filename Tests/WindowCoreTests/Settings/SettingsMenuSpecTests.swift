import XCTest
import WindowCore

final class SettingsMenuSpecTests: XCTestCase {
    private let selfID = AppIdentity.bundleIdentifier
    private let defaults = DefaultShortcuts.bindings

    /// 항목 → 제목, 구분선 → "─", 하위 메뉴 → "제목 ▸(하위 제목들)".
    private func describe(_ items: [SettingsMenuItem]) -> [String] {
        items.map { item in
            switch item {
            case let .item(spec, _, _): return spec.title
            case .separator: return "─"
            case let .submenu(title, children): return "\(title) ▸(\(describe(children).joined(separator: ", ")))"
            }
        }
    }

    private func specs(_ items: [SettingsMenuItem]) -> [(spec: MenuItemSpec, isChecked: Bool?, action: WindowAction?)] {
        items.flatMap { item -> [(spec: MenuItemSpec, isChecked: Bool?, action: WindowAction?)] in
            switch item {
            case let .item(spec, isChecked, action): return [(spec, isChecked, action)]
            case .separator: return []
            case let .submenu(_, children): return specs(children)
            }
        }
    }

    private func control(isPaused: Bool = false, excluded: [String] = [], frontmost: (name: String, bundleID: String)?) -> [SettingsMenuItem] {
        SettingsMenuSpec.control(isPaused: isPaused, excludedBundleIDs: excluded, frontmostApp: frontmost, selfBundleID: selfID)
    }

    private func excludeItem(_ items: [SettingsMenuItem]) -> (spec: MenuItemSpec, isChecked: Bool?, action: WindowAction?) {
        specs(items).first { $0.spec.id == SettingsMenuSpec.excludeFrontmostID }!
    }

    func testKeyEquivalent() {
        XCTAssertEqual(MenuKeyEquivalent.keyEquivalent(for: 0x10), "y")
        XCTAssertEqual(MenuKeyEquivalent.keyEquivalent(for: 0x2B), ",")
        XCTAssertEqual(MenuKeyEquivalent.keyEquivalent(for: 0x2F), ".")
        XCTAssertEqual(MenuKeyEquivalent.keyEquivalent(for: 0x7B), String(UnicodeScalar(0xF702)!))
        XCTAssertEqual(MenuKeyEquivalent.keyEquivalent(for: 0x7A), String(UnicodeScalar(0xF704)!))
        XCTAssertEqual(MenuKeyEquivalent.keyEquivalent(for: 0x31), " ")
        XCTAssertNil(MenuKeyEquivalent.keyEquivalent(for: 0xFF))
        XCTAssertEqual(MenuKeyEquivalent.menuModifiers([.shift, .option, .command]), [.shift, .option, .command])
        XCTAssertEqual(MenuKeyEquivalent.menuModifiers([.control]), [.control])
    }

    func testExcludeFrontmostItem() {
        let safari = (name: "Safari", bundleID: "com.apple.Safari")

        let notExcluded = excludeItem(control(frontmost: safari))
        XCTAssertEqual(notExcluded.spec.title, "\"Safari\"에서 끄기")
        XCTAssertEqual(notExcluded.isChecked, false)
        XCTAssertTrue(notExcluded.spec.isEnabled)

        XCTAssertEqual(excludeItem(control(excluded: ["com.apple.Safari"], frontmost: safari)).isChecked, true)

        let none = excludeItem(control(frontmost: nil))
        XCTAssertEqual(none.spec.title, "이 앱에서 끄기")
        XCTAssertFalse(none.spec.isEnabled)

        let ourselves = excludeItem(control(frontmost: (name: AppIdentity.displayName, bundleID: selfID)))
        XCTAssertEqual(ourselves.spec.title, "이 앱에서 끄기")
        XCTAssertFalse(ourselves.spec.isEnabled)
    }

    // 메뉴에 넣는 다른 앱 표시 이름은 40자까지만
    func testLongAppNameTruncated() {
        let longName = String(repeating: "가", count: 60)
        let item = excludeItem(control(frontmost: (name: longName, bundleID: "com.example.long")))
        XCTAssertEqual(item.spec.title, "\"\(String(repeating: "가", count: 40))…\"에서 끄기")
        let exact = String(repeating: "나", count: 40)
        XCTAssertEqual(excludeItem(control(frontmost: (name: exact, bundleID: "com.example.exact"))).spec.title, "\"\(exact)\"에서 끄기")
    }

    func testPausedDisablesActions() {
        let actionItems = specs(SettingsMenuSpec.arrange(bindings: defaults, isPaused: true))
            + specs(SettingsMenuSpec.history(bindings: defaults, isPaused: true, canUndo: true, canRedo: true))
        XCTAssertEqual(actionItems.count, 14)
        XCTAssertTrue(actionItems.allSatisfy { !$0.spec.isEnabled })

        let pause = specs(control(isPaused: true, frontmost: nil)).first { $0.spec.id == SettingsMenuSpec.pauseID }!
        XCTAssertEqual(pause.isChecked, true)

        let preferences = specs(SettingsMenuSpec.preferences(loginItem: LoginItemPresentation.make(.notFound)))
        for item in preferences where item.spec.id != SettingsMenuSpec.loginItemID {
            XCTAssertTrue(item.spec.isEnabled, item.spec.title)
        }
        XCTAssertFalse(preferences.first { $0.spec.id == SettingsMenuSpec.loginItemID }!.spec.isEnabled)
    }

    func testHistoryAvailability() {
        func enabled(_ items: [SettingsMenuItem]) -> [Bool] { specs(items).map(\.spec.isEnabled) }

        let state = HistoryMenuState()
        XCTAssertEqual(enabled(SettingsMenuSpec.history(bindings: defaults, isPaused: false,
                                                        canUndo: state.canUndo(), canRedo: state.canRedo())), [true, true])

        state.canUndo = { false }
        state.canRedo = { true }
        XCTAssertEqual(enabled(SettingsMenuSpec.history(bindings: defaults, isPaused: false,
                                                        canUndo: state.canUndo(), canRedo: state.canRedo())), [false, true])

        XCTAssertEqual(enabled(SettingsMenuSpec.history(bindings: defaults, isPaused: true,
                                                        canUndo: true, canRedo: true)), [false, false])
    }

    func testItemActions() {
        let arrange = specs(SettingsMenuSpec.arrange(bindings: defaults, isPaused: false)).map(\.action)
        XCTAssertEqual(arrange, Array(WindowAction.allCases.prefix(12)))
        let history = specs(SettingsMenuSpec.history(bindings: defaults, isPaused: false, canUndo: true, canRedo: true)).map(\.action)
        XCTAssertEqual(history, [.undo, .redo])
        let others = specs(control(frontmost: nil)) + specs(SettingsMenuSpec.preferences(loginItem: LoginItemPresentation.make(.enabled)))
        XCTAssertFalse(others.isEmpty)
        XCTAssertTrue(others.allSatisfy { $0.action == nil })
    }

    func testOrder() {
        let arrange = SettingsMenuSpec.arrange(bindings: defaults, isPaused: false)
        XCTAssertEqual(describe(arrange), [
            "좌상단", "상단", "우상단", "좌측", "가운데", "우측", "좌하단", "하단", "우하단", "─",
            "전체화면 채우기", "─", "왼쪽 모니터로", "오른쪽 모니터로",
        ])
        let history = SettingsMenuSpec.history(bindings: defaults, isPaused: false, canUndo: true, canRedo: true)
        XCTAssertEqual(describe(history), ["되돌리기", "다시하기"])
        let control = control(frontmost: (name: "Safari", bundleID: "com.apple.Safari"))
        XCTAssertEqual(describe(control), ["끄기 ▸(잠시 끄기, \"Safari\"에서 끄기)"])
        let preferences = SettingsMenuSpec.preferences(loginItem: LoginItemPresentation.make(.enabled))
        XCTAssertEqual(describe(preferences), ["GridGrip 정보", "설정…", "로그인 시 실행"])
        let settingsItem = specs(preferences).first { $0.spec.id == SettingsMenuSpec.settingsID }!.spec
        XCTAssertEqual(settingsItem.keyEquivalent, ",")
        XCTAssertEqual(settingsItem.modifiers, [.command])

        let composed = MenuLayout.compose([
            .arrange: arrange,
            .history: history,
            .control: control,
            .preferences: preferences,
            .app: SettingsMenuSpec.wrap(BaseMenuSpec.appSection()),
        ])
        let flattened: [String] = composed.flatMap { entry -> [String] in
            switch entry {
            case .separator: return ["═"]
            case let .item(item): return describe([item])
            }
        }
        XCTAssertEqual(flattened, describe(arrange) + ["═"] + describe(history) + ["═"] + describe(control)
            + ["═"] + describe(preferences) + ["═", "GridGrip 종료"])
    }

    func testShortcutDisplay() {
        func item(_ action: WindowAction, _ bindings: ShortcutBindings) -> MenuItemSpec {
            let items = SettingsMenuSpec.arrange(bindings: bindings, isPaused: false)
                + SettingsMenuSpec.history(bindings: bindings, isPaused: false, canUndo: true, canRedo: true)
            return specs(items).first { $0.action == action }!.spec
        }

        XCTAssertEqual(item(.left, defaults).keyEquivalent, "h")
        XCTAssertEqual(item(.left, defaults).modifiers, [.option, .shift, .command])
        XCTAssertEqual(item(.undo, defaults).keyEquivalent, "z")
        XCTAssertEqual(item(.undo, defaults).modifiers, [.option, .command])
        XCTAssertEqual(item(.redo, defaults).keyEquivalent, "z")
        XCTAssertEqual(item(.redo, defaults).modifiers, [.option, .shift, .command])

        var cleared = defaults
        cleared[.left] = nil
        XCTAssertEqual(item(.left, cleared).keyEquivalent, "")
        XCTAssertEqual(item(.left, cleared).modifiers, [])
    }
}
