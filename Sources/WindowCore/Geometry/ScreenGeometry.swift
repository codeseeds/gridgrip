import CoreGraphics

/// 모니터 1대의 frame·visibleFrame (AX 좌표계로 변환 완료 상태).
public struct ScreenGeometry: Equatable {
    public let frame: CGRect
    /// 메뉴바·Dock을 뺀 사용 가능 영역
    public let visibleFrame: CGRect

    public init(frame: CGRect, visibleFrame: CGRect) {
        self.frame = frame
        self.visibleFrame = visibleFrame
    }
}

/// 창이 놓인 모니터 판정.
public enum ScreenSelector {
    /// 창과 교차 면적이 가장 큰 모니터. 교차가 없으면 창 중심과 모니터 frame 중심이 가장 가까운 모니터. 목록이 비면 nil.
    public static func screen(for window: CGRect, among screens: [ScreenGeometry]) -> ScreenGeometry? {
        var best: (screen: ScreenGeometry, area: CGFloat)?
        for screen in screens {
            let overlap = screen.frame.intersection(window)
            guard !overlap.isNull else { continue }
            let area = overlap.width * overlap.height
            if area > 0, area > (best?.area ?? 0) {
                best = (screen, area)
            }
        }
        if let best { return best.screen }

        let center = CGPoint(x: window.midX, y: window.midY)
        return screens.min { distanceSquared($0.frame, center) < distanceSquared($1.frame, center) }
    }

    private static func distanceSquared(_ rect: CGRect, _ point: CGPoint) -> CGFloat {
        let dx = rect.midX - point.x
        let dy = rect.midY - point.y
        return dx * dx + dy * dy
    }
}
