import AppKit
import WindowCore

/// `NSScreen.screens` → AX 좌표계 `[ScreenGeometry]`. 좌표 변환은 여기서 1회만 한다.
enum ScreenProvider {
    /// 기준 높이 = 메뉴바가 있는 주 모니터(`NSScreen.screens[0]`)의 높이. 화면이 0개면 빈 배열.
    static func current() -> [ScreenGeometry] {
        let screens = NSScreen.screens
        guard let primary = screens.first else { return [] }
        let primaryHeight = primary.frame.height
        return screens.map {
            ScreenGeometry(frame: CoordinateConverter.toAX($0.frame, primaryHeight: primaryHeight),
                           visibleFrame: CoordinateConverter.toAX($0.visibleFrame, primaryHeight: primaryHeight))
        }
    }
}
