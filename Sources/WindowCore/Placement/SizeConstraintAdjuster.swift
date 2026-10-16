import CoreGraphics

/// 창이 목표 크기를 못 맞췄을 때(최소 크기·크기 고정) 위치 보정. 결과 크기는 항상 실제 크기다.
public enum SizeConstraintAdjuster {
    /// 배치의 기준 가장자리를 유지한다: 오른쪽 기준(I·K·M) `x = visible.maxX − 실제폭`,
    /// 아래 기준(B·N·M) `y = visible.maxY − 실제높이`, 가운데(J)는 재중앙, 왼쪽·위 기준은 그대로.
    /// 실제 크기가 visible보다 크면 그 축은 visible의 왼쪽·위에 맞춘다(제목줄이 화면 밖으로 나가지 않게).
    public static func adjust(target: CGRect, actualSize: CGSize, placement: Placement, in visible: CGRect) -> CGRect {
        var x = target.minX
        var y = target.minY
        if placement == .center {
            x = visible.minX + (visible.width - actualSize.width) / 2
            y = visible.minY + (visible.height - actualSize.height) / 2
        } else {
            if placement.anchorsRight { x = visible.maxX - actualSize.width }
            if placement.anchorsBottom { y = visible.maxY - actualSize.height }
        }
        if actualSize.width > visible.width { x = visible.minX }
        if actualSize.height > visible.height { y = visible.minY }
        return CGRect(x: x.rounded(), y: y.rounded(), width: actualSize.width, height: actualSize.height)
    }

    /// 모니터 이동용(기준 가장자리 없음): 실제 크기 기준으로 visible 안으로 밀어 넣고, 크면 왼쪽·위에 맞춘다
    public static func fit(target: CGRect, actualSize: CGSize, in visible: CGRect) -> CGRect {
        func clamp(_ value: CGFloat, _ length: CGFloat, _ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
            length > upper - lower ? lower : min(max(value, lower), upper - length)
        }
        let x = clamp(target.minX, actualSize.width, visible.minX, visible.maxX)
        let y = clamp(target.minY, actualSize.height, visible.minY, visible.maxY)
        return CGRect(x: x.rounded(), y: y.rounded(), width: actualSize.width, height: actualSize.height)
    }
}
