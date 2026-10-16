import AppKit

// SwiftUI `@main App` 대신 AppKit 진입점 — 메뉴바 전용 앱이라 장면 관리가 필요 없다.
MainActor.assumeIsolated {
    let app = NSApplication.shared
    // Info.plist LSUIElement와 이중 적용 — 번들 없이 실행(swift run)해도 Dock 아이콘이 뜨지 않게 한다.
    app.setActivationPolicy(.accessory)
    let delegate = AppDelegate()
    app.delegate = delegate
    // NSApplication.delegate는 약한 참조이므로 run() 동안 delegate를 붙잡아 둔다.
    withExtendedLifetime(delegate) {
        app.run()
    }
}
