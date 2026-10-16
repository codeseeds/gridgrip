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
            button.image = Self.makeIcon()
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

    /// 앱 아이콘의 격자를 단색 템플릿으로 그린다. 색은 메뉴바 모양(라이트·다크·강조)에 맞춰 시스템이 입힌다.
    private static func makeIcon() -> NSImage {
        let size = StatusIconGlyph.canvasSize
        let image = NSImage(size: NSSize(width: size, height: size), flipped: true) { _ in
            let radius = StatusIconGlyph.cornerRadius()
            for cell in StatusIconGlyph.cells() {
                let path = NSBezierPath(roundedRect: cell.rect, xRadius: radius, yRadius: radius)
                if cell.rotationDegrees != 0 {
                    var transform = AffineTransform(translationByX: cell.rect.midX, byY: cell.rect.midY)
                    transform.rotate(byDegrees: cell.rotationDegrees)
                    transform.translate(x: -cell.rect.midX, y: -cell.rect.midY)
                    path.transform(using: transform)
                }
                NSColor.black.withAlphaComponent(cell.opacity).setFill()
                path.fill()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = AppIdentity.displayName
        return image
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
