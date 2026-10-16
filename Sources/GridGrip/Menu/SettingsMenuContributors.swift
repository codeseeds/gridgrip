import AppKit
import WindowCore

/// `SettingsMenuItem` → NSMenuItem 변환과 클릭 전달. 메뉴는 열릴 때마다 새로 만든다.
@MainActor
final class SettingsMenuItemFactory: NSObject {
    private let onSelect: (_ id: String, _ action: WindowAction?) -> Void

    init(onSelect: @escaping (_ id: String, _ action: WindowAction?) -> Void) {
        self.onSelect = onSelect
    }

    func makeItems(_ items: [SettingsMenuItem]) -> [NSMenuItem] {
        items.map(makeItem)
    }

    private func makeItem(_ item: SettingsMenuItem) -> NSMenuItem {
        switch item {
        case .separator:
            return .separator()
        case let .submenu(title, children):
            let menuItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            let submenu = NSMenu(title: title)
            submenu.autoenablesItems = false
            makeItems(children).forEach(submenu.addItem)
            menuItem.submenu = submenu
            return menuItem
        case let .item(spec, isChecked, action):
            // 오른쪽 단축키 표시는 시스템이 그린다. 전역 단축키는 Carbon이 먼저 가로챈다.
            let menuItem = NSMenuItem(title: spec.title, action: #selector(selected(_:)), keyEquivalent: spec.keyEquivalent)
            menuItem.keyEquivalentModifierMask = Self.modifierFlags(spec.modifiers)
            menuItem.identifier = NSUserInterfaceItemIdentifier(spec.id)
            menuItem.isEnabled = spec.isEnabled
            menuItem.state = isChecked == true ? .on : .off
            menuItem.representedObject = action?.rawValue
            menuItem.target = self
            return menuItem
        }
    }

    @objc private func selected(_ sender: NSMenuItem) {
        guard let id = sender.identifier?.rawValue else { return }
        let action = (sender.representedObject as? String).flatMap(WindowAction.init(rawValue:))
        onSelect(id, action)
    }

    private static func modifierFlags(_ modifiers: MenuModifiers) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if modifiers.contains(.command) { flags.insert(.command) }
        if modifiers.contains(.option) { flags.insert(.option) }
        if modifiers.contains(.shift) { flags.insert(.shift) }
        if modifiers.contains(.control) { flags.insert(.control) }
        return flags
    }
}

/// arrange 슬롯: 9칸·전체화면 채우기·모니터 이동. 클릭은 단축키와 같은 `dispatch` 경로.
@MainActor
final class ActionMenuContributor: MenuContributor {
    let slot = MenuSectionSlot.arrange
    private let engine: ShortcutEngine
    private let activation: ActivationPolicy
    private lazy var factory = SettingsMenuItemFactory { [dispatcher] _, action in
        if let action { dispatcher.dispatch(action) }
    }
    private let dispatcher: ActionDispatcher

    init(engine: ShortcutEngine, activation: ActivationPolicy, dispatcher: ActionDispatcher) {
        self.engine = engine
        self.activation = activation
        self.dispatcher = dispatcher
    }

    func menuItems() -> [NSMenuItem] {
        factory.makeItems(SettingsMenuSpec.arrange(bindings: engine.bindings, isPaused: activation.isPaused))
    }
}

/// history 슬롯: 되돌리기·다시하기. 활성 여부는 되돌리기 기능이 `HistoryMenuState` 클로저로 제공한다.
@MainActor
final class HistoryMenuContributor: MenuContributor {
    let slot = MenuSectionSlot.history
    private let engine: ShortcutEngine
    private let activation: ActivationPolicy
    private let historyState: HistoryMenuState
    private let dispatcher: ActionDispatcher
    private lazy var factory = SettingsMenuItemFactory { [dispatcher] _, action in
        if let action { dispatcher.dispatch(action) }
    }

    init(engine: ShortcutEngine, activation: ActivationPolicy, historyState: HistoryMenuState, dispatcher: ActionDispatcher) {
        self.engine = engine
        self.activation = activation
        self.historyState = historyState
        self.dispatcher = dispatcher
    }

    func menuItems() -> [NSMenuItem] {
        factory.makeItems(SettingsMenuSpec.history(bindings: engine.bindings, isPaused: activation.isPaused,
                                                   canUndo: historyState.canUndo(), canRedo: historyState.canRedo()))
    }
}

/// control 슬롯: "끄기 ▸"(잠시 끄기 / "{앱}"에서 끄기). 변경은 `ActivationPolicy.update` 한 경로로만 한다.
@MainActor
final class ControlMenuContributor: MenuContributor {
    let slot = MenuSectionSlot.control
    private let activation: ActivationPolicy
    /// 메뉴를 연 순간의 맨 앞 앱(메뉴바 클릭은 우리 앱을 활성화하지 않으므로 사용자가 쓰던 앱).
    private var menuFrontmostBundleID: String?
    private lazy var factory = SettingsMenuItemFactory { [weak self] id, _ in
        self?.selected(id)
    }

    init(activation: ActivationPolicy) {
        self.activation = activation
    }

    func menuItems() -> [NSMenuItem] {
        let app = NSWorkspace.shared.frontmostApplication
        menuFrontmostBundleID = app?.bundleIdentifier
        let frontmost = app?.bundleIdentifier.map { (name: app?.localizedName ?? $0, bundleID: $0) }
        return factory.makeItems(SettingsMenuSpec.control(isPaused: activation.isPaused,
                                                          excludedBundleIDs: activation.excludedBundleIDs,
                                                          frontmostApp: frontmost,
                                                          selfBundleID: AppIdentity.bundleIdentifier))
    }

    private func selected(_ id: String) {
        switch id {
        case SettingsMenuSpec.pauseID:
            activation.update(isPaused: !activation.isPaused)
        case SettingsMenuSpec.excludeFrontmostID:
            guard let bundleID = menuFrontmostBundleID else { return }
            var settings = GeneralSettings(policy: activation)
            guard settings.toggleExcluded(bundleID, selfBundleID: AppIdentity.bundleIdentifier) else { return }
            activation.update(excludedBundleIDs: settings.excludedBundleIDs)
        default:
            break
        }
    }
}

/// preferences 슬롯: 정보·설정…·로그인 시 실행.
@MainActor
final class PreferencesMenuContributor: MenuContributor {
    let slot = MenuSectionSlot.preferences
    private let settingsWindow: SettingsWindowController
    private let loginItems = LoginItemService()
    private lazy var factory = SettingsMenuItemFactory { [weak self] id, _ in
        self?.selected(id)
    }

    init(settingsWindow: SettingsWindowController) {
        self.settingsWindow = settingsWindow
    }

    func menuItems() -> [NSMenuItem] {
        factory.makeItems(SettingsMenuSpec.preferences(loginItem: LoginItemPresentation.make(loginItems.status)))
    }

    private func selected(_ id: String) {
        switch id {
        case SettingsMenuSpec.aboutID:
            NSApp.activate(ignoringOtherApps: true)
            NSApp.orderFrontStandardAboutPanel(nil)
        case SettingsMenuSpec.settingsID:
            settingsWindow.showWindow()
        case SettingsMenuSpec.loginItemID:
            let current = LoginItemPresentation.make(loginItems.status)
            let result = loginItems.setEnabled(!current.isChecked)
            let presentation = LoginItemPresentation.afterToggle(actual: result.status, errorDescription: result.errorDescription)
            settingsWindow.refresh()
            // 메뉴에는 안내 줄이 없으므로 승인 필요·실패는 대화상자로 알린다.
            if let message = presentation.message {
                showLoginItemNotice(message, showsOpenSettings: presentation.showsOpenSettings)
            }
        default:
            break
        }
    }

    private func showLoginItemNotice(_ message: String, showsOpenSettings: Bool) {
        let alert = NSAlert()
        alert.messageText = SettingsFormLayout.loginItemTitle
        alert.informativeText = message
        alert.addButton(withTitle: L10n.tr("OK"))
        if showsOpenSettings {
            alert.addButton(withTitle: SettingsFormLayout.openSystemSettingsTitle)
        }
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertSecondButtonReturn {
            loginItems.openSystemSettings()
        }
    }
}
