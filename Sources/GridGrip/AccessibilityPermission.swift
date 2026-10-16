import AppKit
import ApplicationServices

/// 손쉬운 사용 권한 확인·시스템 설정 열기.
/// AX 권한 API(`AXIsProcessTrustedWithOptions`) 호출은 앱 전체에서 이 파일에만 둔다. 사적 API 금지.
struct AccessibilityPermission {
    private static let accessibilitySettingsURL =
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")

    /// prompt가 true면 시스템이 권한 요청 창을 띄우고 앱을 손쉬운 사용 목록에 등록한다.
    func isTrusted(prompt: Bool) -> Bool {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([promptKey: prompt] as CFDictionary)
    }

    /// 목록 등록을 위해 `prompt: true`로 1회 확인한 뒤 손쉬운 사용 설정 화면을 연다.
    /// 이때 macOS 자체 권한 요청 창이 설정 창과 함께 뜰 수 있다(정상).
    func openSystemSettings() {
        _ = isTrusted(prompt: true)
        if let url = Self.accessibilitySettingsURL {
            NSWorkspace.shared.open(url)
        }
    }
}
