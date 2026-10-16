import AppKit
import WindowCore

/// 권한 안내·원본 앱 동시 실행 안내 대화상자. 호출하는 쪽에서 순차로 띄운다(겹쳐 띄우지 않음).
@MainActor
enum Alerts {
    /// [시스템 설정 열기]를 고르면 true.
    static func showPermissionAlert() -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L10n.tr("%1$@ needs %2$@ permission",
                                    AppIdentity.displayName, SystemSettingsPaths.accessibilityPermissionName())
        alert.informativeText = L10n.tr("To move and resize windows, turn on %1$@ in %2$@.",
                                        AppIdentity.displayName, SystemSettingsPaths.accessibilityPermission())
        alert.addButton(withTitle: SettingsFormLayout.openSystemSettingsTitle)
        alert.addButton(withTitle: L10n.tr("Later"))
        bringToFront()
        return alert.runModal() == .alertFirstButtonReturn
    }

    static func showConflictNotice(_ apps: [KnownConflictingApp]) {
        let names = apps.map(\.displayName).joined(separator: ", ")
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = L10n.tr("Another window manager is running")
        alert.informativeText = L10n.tr("While %@ is running, shortcuts may conflict. Quitting it is recommended.", names)
        alert.addButton(withTitle: L10n.tr("OK"))
        bringToFront()
        alert.runModal()
    }

    /// accessory 앱은 활성화하지 않으면 대화상자가 다른 창 뒤에 숨는다.
    private static func bringToFront() {
        NSApp.activate(ignoringOtherApps: true)
    }
}
