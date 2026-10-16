import CoreGraphics

/// 배치 목표 프레임 계산. 모든 좌표는 AX 좌표계(주 모니터 좌상단 원점, y 아래로 증가).
public enum PlacementCalculator {
    /// 각 가장자리 좌표를 정수로 반올림한 뒤 폭·높이를 그 차로 정한다(좌·우 1/2이 틈·겹침 없이 맞물리게).
    public static func frame(for placement: Placement, ratio: CGFloat, in visible: CGRect, currentSize: CGSize) -> CGRect {
        let minX = visible.minX.rounded()
        let maxX = visible.maxX.rounded()
        let minY = visible.minY.rounded()
        let maxY = visible.maxY.rounded()

        switch placement {
        case .fill:
            return edges(minX, minY, maxX, maxY)
        case .center:
            let width = min(currentSize.width, visible.width).rounded()
            let height = min(currentSize.height, visible.height).rounded()
            let x = (visible.minX + (visible.width - width) / 2).rounded()
            let y = (visible.minY + (visible.height - height) / 2).rounded()
            return CGRect(x: x, y: y, width: width, height: height)
        default:
            break
        }

        let fullWidth = placement == .top || placement == .bottom
        let fullHeight = placement == .left || placement == .right
        let width = fullWidth ? visible.width : visible.width * ratio
        let height = fullHeight ? visible.height : visible.height * ratio

        let (left, right) = placement.anchorsRight
            ? ((visible.maxX - width).rounded(), maxX)
            : (minX, (visible.minX + width).rounded())
        let (top, bottom) = placement.anchorsBottom
            ? ((visible.maxY - height).rounded(), maxY)
            : (minY, (visible.minY + height).rounded())
        return edges(left, top, right, bottom)
    }

    private static func edges(_ minX: CGFloat, _ minY: CGFloat, _ maxX: CGFloat, _ maxY: CGFloat) -> CGRect {
        CGRect(x: minX, y: minY, width: max(0, maxX - minX), height: max(0, maxY - minY))
    }
}
