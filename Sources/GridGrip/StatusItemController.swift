import AppKit
import WindowCore

/// 메뉴바 아이콘과 드롭다운 메뉴. 메뉴는 열릴 때마다 현재 권한 상태와 기여자 항목으로 다시 구성한다.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private let contributors: [MenuContributor]
    private let permission: () -> PermissionState
    private let openSystemSettings: () -> Void

    init(contributors: [MenuContributor], permission: @escaping () -> PermissionState, openSystemSettings: @escaping () -> Void) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.contributors = contributors
        self.permission = permission
        self.openSystemSettings = openSystemSettings
        super.init()

        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "macwindow", accessibilityDescription: AppIdentity.displayName)
            image?.isTemplate = true
            button.image = image
            button.setAccessibilityLabel(AppIdentity.displayName)
        }
        menu.autoenablesItems = false
        menu.delegate = self
        statusItem.menu = menu
        rebuildMenu()
    }

    /// 메뉴가 열려 있을 때도 즉시 다시 구성한다 (`ctx.requestMenuRebuild()` 경로).
    func rebuildMenu() {
        var sections: [MenuSectionSlot: [NSMenuItem]] = [:]
        sections[.permission] = BaseMenuSpec.permissionSection(permission()).map(makeItem)
        for contributor in contributors {
            sections[contributor.slot, default: []] += contributor.menuItems()
        }
        // 종료 항목은 항상 마지막.
        sections[.app, default: []] += BaseMenuSpec.appSection().map(makeItem)

        menu.removeAllItems()
        for entry in MenuLayout.compose(sections) {
            switch entry {
            case let .item(item): menu.addItem(item)
            case .separator: menu.addItem(.separator())
            }
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildMenu()
    }

    private func makeItem(_ spec: MenuItemSpec) -> NSMenuItem {
        let item = NSMenuItem(title: spec.title, action: action(for: spec.id), keyEquivalent: spec.keyEquivalent)
        item.identifier = NSUserInterfaceItemIdentifier(spec.id)
        item.keyEquivalentModifierMask = Self.modifierFlags(spec.modifiers)
        item.isEnabled = spec.isEnabled
        item.target = item.action == nil ? nil : self
        return item
    }

    private func action(for id: String) -> Selector? {
        switch id {
        case BaseMenuSpec.openSystemSettingsID: return #selector(openSystemSettingsSelected(_:))
        case BaseMenuSpec.quitID: return #selector(quitSelected(_:))
        default: return nil
        }
    }

    private static func modifierFlags(_ modifiers: MenuModifiers) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if modifiers.contains(.command) { flags.insert(.command) }
        if modifiers.contains(.option) { flags.insert(.option) }
        if modifiers.contains(.shift) { flags.insert(.shift) }
        if modifiers.contains(.control) { flags.insert(.control) }
        return flags
    }

    @objc private func openSystemSettingsSelected(_ sender: NSMenuItem) {
        openSystemSettings()
    }

    @objc private func quitSelected(_ sender: NSMenuItem) {
        NSApp.terminate(nil)
    }
}
