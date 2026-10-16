import CoreGraphics

/// 크기조정 하한 (제목줄·신호등 버튼이 남는 보수적 값).
public enum MouseDragGeometry {
    public static let minimumSize = CGSize(width: 120, height: 80)

    /// 출력에만 적용한다. 누적 델타는 깎지 않는다(되키울 때 커서와 모서리가 어긋나지 않게).
    public static func clampedSize(_ size: CGSize) -> CGSize {
        CGSize(width: max(size.width, minimumSize.width), height: max(size.height, minimumSize.height))
    }
}
