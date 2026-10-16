import CoreGraphics

/// 다른 모니터로 보내기. 맨 끝에서는 반대쪽 끝으로 순환한다.
public enum DisplayMover {
    /// frame.minX 오름차순, 같으면 minY 오름차순(AX 좌표에서 위쪽 먼저).
    public static func orderedScreens(_ screens: [ScreenGeometry]) -> [ScreenGeometry] {
        screens.sorted { lhs, rhs in
            lhs.frame.minX != rhs.frame.minX ? lhs.frame.minX < rhs.frame.minX : lhs.frame.minY < rhs.frame.minY
        }
    }

    /// 보낼 모니터. 모니터가 1대 이하이거나 `from`이 목록에 없으면 nil.
    public static func destination(from: ScreenGeometry, screens: [ScreenGeometry], direction: DisplayDirection) -> ScreenGeometry? {
        let ordered = orderedScreens(screens)
        guard ordered.count > 1, let index = ordered.firstIndex(of: from) else { return nil }
        let step = direction == .next ? 1 : -1
        return ordered[(index + step + ordered.count) % ordered.count]
    }

    /// 원래 visibleFrame 안의 상대 위치·크기를 새 visibleFrame에 옮긴 목표 프레임(가장자리 정수 반올림).
    /// 새 visibleFrame을 벗어나면 크기는 visible 크기로 줄이고 위치는 안으로 밀어 넣는다.
    public static func target(window: CGRect, from: ScreenGeometry, screens: [ScreenGeometry], direction: DisplayDirection) -> CGRect? {
        guard let to = destination(from: from, screens: screens, direction: direction) else { return nil }
        let source = from.visibleFrame
        let dest = to.visibleFrame
        guard source.width > 0, source.height > 0 else { return nil }

        let rx = (window.minX - source.minX) / source.width
        let ry = (window.minY - source.minY) / source.height
        let rw = window.width / source.width
        let rh = window.height / source.height

        let minX = (dest.minX + rx * dest.width).rounded()
        let minY = (dest.minY + ry * dest.height).rounded()
        let width = min((dest.minX + (rx + rw) * dest.width).rounded() - minX, dest.width.rounded())
        let height = min((dest.minY + (ry + rh) * dest.height).rounded() - minY, dest.height.rounded())
        let moved = CGRect(x: minX, y: minY, width: max(0, width), height: max(0, height))
        return SizeConstraintAdjuster.fit(target: moved, actualSize: moved.size, in: dest)
    }
}
