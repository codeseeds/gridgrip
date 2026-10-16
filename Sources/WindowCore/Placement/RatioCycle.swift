import CoreGraphics

/// 같은 키·같은 창 연속 입력 판정. 메모리에만 두는 값 상태(저장하지 않음).
/// 창 동일성은 `W`의 `==`(실행 타깃에선 `AXWindowElement` = pid + `CFEqual`).
///
/// `nextRatio`는 고른 비율을 "대기 중" 값으로만 잡아 두고, `record`가 그 값을 확정한다.
/// `nextRatio` 뒤 `record`가 오지 않으면 직전 기록이 그대로 남아 판정 기준이 된다.
public struct RatioCycle<W: Equatable> {
    private struct Entry {
        let placement: Placement
        let window: W
        let frame: CGRect
        let index: Int
    }

    private struct Pending {
        let placement: Placement
        let window: W
        let index: Int
    }

    private var last: Entry?
    private var pending: Pending?

    public init() {}

    /// 직전 기록과 (같은 배치) AND (같은 창) AND (현재 프레임 ≈ 기록 프레임, 2pt)이면 다음 비율, 아니면 1/3.
    public mutating func nextRatio(for placement: Placement, window: W, currentFrame: CGRect) -> CGFloat {
        var index = 0
        if let last, last.placement == placement, last.window == window,
           FrameTolerance.isSame(last.frame, currentFrame) {
            index = (last.index + 1) % PlacementRatio.cycle.count
        }
        pending = Pending(placement: placement, window: window, index: index)
        return PlacementRatio.cycle[index]
    }

    /// 적용 후 다시 읽은 실제 프레임(또는 "변화 없음"일 때 현재 프레임)을 기록한다.
    /// 직전 `nextRatio`와 배치·창이 같으면 그때 고른 비율로, 아니면 1/3로 기록한다.
    public mutating func record(placement: Placement, window: W, frame: CGRect) {
        var index = 0
        if let pending, pending.placement == placement, pending.window == window {
            index = pending.index
        }
        last = Entry(placement: placement, window: window, frame: frame, index: index)
        pending = nil
    }

    public mutating func reset() {
        last = nil
        pending = nil
    }
}
