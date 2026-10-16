import AppKit
import WindowCore

/// 권한 안내·원본 앱 동시 실행 안내 대화상자. 호출하는 쪽에서 순차로 띄운다(겹쳐 띄우지 않음).
@MainActor
enum Alerts {
    /// [시스템 설정 열기]를 고르면 true.
    static func showPermissionAlert() -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "\(AppIdentity.displayName)에 손쉬운 사용 권한이 필요합니다"
        alert.informativeText = "창을 옮기고 크기를 바꾸려면 시스템 설정 > 개인정보 보호 및 보안 > 손쉬운 사용에서 \(AppIdentity.displayName)를 켜 주세요."
        alert.addButton(withTitle: "시스템 설정 열기")
        alert.addButton(withTitle: "나중에")
        bringToFront()
        return alert.runModal() == .alertFirstButtonReturn
    }

    static func showConflictNotice(_ apps: [KnownConflictingApp]) {
        let names = apps.map(\.displayName).joined(separator: ", ")
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "기존 창 관리 앱이 실행 중입니다"
        alert.informativeText = "\(names)가 실행 중이면 단축키가 겹칠 수 있습니다. 해당 앱을 종료하는 것을 권장합니다."
        alert.addButton(withTitle: "확인")
        bringToFront()
        alert.runModal()
    }

    /// accessory 앱은 활성화하지 않으면 대화상자가 다른 창 뒤에 숨는다.
    private static func bringToFront() {
        NSApp.activate(ignoringOtherApps: true)
    }
}
