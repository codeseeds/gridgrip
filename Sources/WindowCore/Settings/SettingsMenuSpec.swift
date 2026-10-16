import Foundation

/// `MenuItemSpec`(체크 필드 없음)를 감싸 체크·하위 메뉴·슬롯 내부 구분선을 표현한다.
/// `isChecked == nil`이면 체크 표시 없는 일반 항목, `action`이 있으면 클릭 시 디스패처로 보낸다.
public enum SettingsMenuItem: Equatable {
    case item(spec: MenuItemSpec, isChecked: Bool?, action: WindowAction?)
    case submenu(title: String, children: [SettingsMenuItem])
    case separator
}

/// 슬롯별 메뉴 항목 정본(순서·제목·단축키·체크·활성). 실행 타깃의 메뉴 기여자는 이 결과를 NSMenuItem으로 바꾸기만 한다.
public enum SettingsMenuSpec {
    public static let pauseID = "control.pause"
    public static let excludeFrontmostID = "control.excludeFrontmost"
    public static let aboutID = "preferences.about"
    public static let settingsID = "preferences.settings"
    public static let loginItemID = "preferences.loginItem"

    public static let disableMenuTitle = "끄기"
    public static let pauseTitle = "잠시 끄기"
    public static let excludeUnavailableTitle = "이 앱에서 끄기"
    /// 다른 앱이 스스로 정한 표시 이름을 메뉴에 넣을 때의 최대 글자 수.
    public static let maxAppNameLength = 40

    /// 9칸 → 구분선 → 전체화면 채우기 → 구분선 → 왼쪽/오른쪽 모니터로.
    public static func arrange(bindings: ShortcutBindings, isPaused: Bool) -> [SettingsMenuItem] {
        let grid: [WindowAction] = [.topLeft, .top, .topRight, .left, .center, .right, .bottomLeft, .bottom, .bottomRight]
        let display: [WindowAction] = [.previousDisplay, .nextDisplay]
        func items(_ actions: [WindowAction]) -> [SettingsMenuItem] {
            actions.map { actionItem($0, bindings: bindings, isEnabled: !isPaused) }
        }
        return items(grid) + [.separator] + items([.fill]) + [.separator] + items(display)
    }

    public static func history(bindings: ShortcutBindings, isPaused: Bool, canUndo: Bool, canRedo: Bool) -> [SettingsMenuItem] {
        [
            actionItem(.undo, bindings: bindings, isEnabled: !isPaused && canUndo),
            actionItem(.redo, bindings: bindings, isEnabled: !isPaused && canRedo),
        ]
    }

    /// "끄기 ▸" 하위 메뉴. 맨 앞 앱이 없음·번들 ID 없음·우리 앱 자신이면 제외 항목을 비활성화한다.
    public static func control(isPaused: Bool,
                               excludedBundleIDs: [String],
                               frontmostApp: (name: String, bundleID: String)?,
                               selfBundleID: String) -> [SettingsMenuItem] {
        let pause = SettingsMenuItem.item(spec: MenuItemSpec(id: pauseID, title: pauseTitle), isChecked: isPaused, action: nil)

        let exclude: SettingsMenuItem
        if let app = frontmostApp, !app.bundleID.isEmpty,
           app.bundleID.caseInsensitiveCompare(selfBundleID) != .orderedSame {
            let isExcluded = ActivationPolicy(excludedBundleIDs: excludedBundleIDs).isExcluded(bundleIdentifier: app.bundleID)
            exclude = .item(spec: MenuItemSpec(id: excludeFrontmostID, title: "\"\(truncated(app.name))\"에서 끄기"),
                            isChecked: isExcluded, action: nil)
        } else {
            exclude = .item(spec: MenuItemSpec(id: excludeFrontmostID, title: excludeUnavailableTitle, isEnabled: false),
                            isChecked: false, action: nil)
        }
        return [.submenu(title: disableMenuTitle, children: [pause, exclude])]
    }

    public static func preferences(loginItem: LoginItemPresentation) -> [SettingsMenuItem] {
        [
            .item(spec: MenuItemSpec(id: aboutID, title: "\(AppIdentity.displayName) 정보"), isChecked: nil, action: nil),
            .item(spec: MenuItemSpec(id: settingsID, title: "설정…", keyEquivalent: ",", modifiers: [.command]),
                  isChecked: nil, action: nil),
            .item(spec: MenuItemSpec(id: loginItemID, title: SettingsFormLayout.loginItemTitle, isEnabled: loginItem.isEnabled),
                  isChecked: loginItem.isChecked, action: nil),
        ]
    }

    /// 기본 메뉴 섹션을 `MenuLayout.compose<SettingsMenuItem>`에 함께 넣기 위해 감싼다.
    public static func wrap(_ specs: [MenuItemSpec]) -> [SettingsMenuItem] {
        specs.map { .item(spec: $0, isChecked: nil, action: nil) }
    }

    public static func actionID(_ action: WindowAction) -> String {
        "action.\(action.rawValue)"
    }

    private static func truncated(_ name: String) -> String {
        name.count > maxAppNameLength ? String(name.prefix(maxAppNameLength)) + "…" : name
    }

    /// 지운 단축키는 표시 없음(keyEquivalent "").
    private static func actionItem(_ action: WindowAction, bindings: ShortcutBindings, isEnabled: Bool) -> SettingsMenuItem {
        var keyEquivalent = ""
        var modifiers: MenuModifiers = []
        if let combo = bindings[action], let key = MenuKeyEquivalent.keyEquivalent(for: combo.keyCode) {
            keyEquivalent = key
            modifiers = MenuKeyEquivalent.menuModifiers(combo.modifiers)
        }
        let spec = MenuItemSpec(id: actionID(action), title: SettingsFormLayout.title(for: action),
                                keyEquivalent: keyEquivalent, modifiers: modifiers, isEnabled: isEnabled)
        return .item(spec: spec, isChecked: nil, action: action)
    }
}
