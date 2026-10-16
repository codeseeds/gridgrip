import CoreGraphics

/// 좌하단 원점(NSScreen/Cocoa) ↔ 좌상단 원점(AX) 변환. 기준은 주 모니터(메뉴바 있는 모니터) 높이.
/// 공식이 자기 자신의 역함수라 두 방향 모두 `y' = primaryHeight - rect.maxY`.
public enum CoordinateConverter {
    public static func toAX(_ cocoaRect: CGRect, primaryHeight: CGFloat) -> CGRect {
        flip(cocoaRect, primaryHeight: primaryHeight)
    }

    public static func toCocoa(_ axRect: CGRect, primaryHeight: CGFloat) -> CGRect {
        flip(axRect, primaryHeight: primaryHeight)
    }

    private static func flip(_ rect: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(x: rect.origin.x, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }
}
