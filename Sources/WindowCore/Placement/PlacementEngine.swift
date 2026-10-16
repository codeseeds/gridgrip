import CoreGraphics

/// 배치 명령 1건의 실행 결과. 되돌리기 기록 여부의 근거다.
public enum PlacementOutcome: Equatable {
    /// before = 어떤 쓰기보다 먼저 읽은 프레임, after = 적용·보정 후 다시 읽은 실제 프레임
    case applied(before: CGRect, after: CGRect)
    case noChange
    case failed(PlacementFailure)
}

public enum PlacementFailure: Equatable {
    case readFailed(WindowOpError)
    case noScreen
    case minimized
    case fullScreen
    case windowGone
    case writeFailed(WindowOpError?)
}

/// 명령 1건 수행: 읽기 → (최소화·전체화면 확인) → 모니터 판정 → 계산 → (변화 없음 판정) → 적용 → 보정
/// → 다시 읽기 → 사이클 갱신. 기록(`WindowChangeHub`)은 호출측이 `.applied`일 때만 한다.
/// 사이클 상태(`RatioCycle<W>`)를 보유하므로 앱 생애 동안 인스턴스 1개를 쓴다. 메인 스레드에서만 사용한다.
public final class PlacementEngine<W: PlaceableWindow & Equatable> {
    private var cycle = RatioCycle<W>()

    public init() {}

    public func perform(_ command: PlacementCommand, on window: W, screens: [ScreenGeometry]) -> PlacementOutcome {
        // ① 쓰기 전 프레임
        let before: CGRect
        switch window.readFrame() {
        case .success(let frame):
            before = frame
        case .failure(.windowGone):
            return fail(.windowGone)
        case .failure(let error):
            return fail(.readFailed(error))
        }

        // ②
        if window.isMinimized { return fail(.minimized) }
        if window.isFullScreen { return fail(.fullScreen) }

        // ③
        guard let screen = ScreenSelector.screen(for: before, among: screens) else { return fail(.noScreen) }

        // ④ 목표 계산. 크기 조절 불가 창은 쓰기 전에 현재 크기 기준으로 위치를 보정한다.
        let canResize = window.isResizable
        let placement: Placement?
        let visible: CGRect
        var target: CGRect
        switch command {
        case .place(let p):
            placement = p
            visible = screen.visibleFrame
            let ratio = p.usesRatioCycle
                ? cycle.nextRatio(for: p, window: window, currentFrame: before)
                : PlacementRatio.cycle[0]
            target = PlacementCalculator.frame(for: p, ratio: ratio, in: visible, currentSize: before.size)
        case .moveToDisplay(let direction):
            placement = nil
            guard let destination = DisplayMover.destination(from: screen, screens: screens, direction: direction),
                  let moved = DisplayMover.target(window: before, from: screen, screens: screens, direction: direction) else {
                cycle.reset()
                return .noChange
            }
            visible = destination.visibleFrame
            target = moved
        }
        if !canResize {
            target = correct(target, actualSize: before.size, placement: placement, in: visible)
        }

        // ⑤ 변화 없음
        if FrameTolerance.isSame(target, before) {
            return noChange(placement, window: window, frame: before)
        }

        // ⑥ 적용 — 결과는 다시 읽은 실제 프레임으로 판정
        var after: CGRect
        switch FrameWriter.apply(target, to: window, canResize: canResize) {
        case .reached(let actual), .partial(let actual):
            after = actual
        case .windowGone:
            return fail(.windowGone)
        case .failed(nil):
            // 모든 쓰기가 오류 없이 끝났는데 앱이 거부해 창이 그대로 → "변화 없음"과 같게 처리.
            // 사이클을 초기화하면 최소 크기·글자 단위 스냅 창이 1/3에서 영원히 못 넘어간다.
            return noChange(placement, window: window, frame: before)
        case .failed(let error):
            return fail(.writeFailed(error))
        }

        // ⑦ 최소 크기 보정 — 실제 크기가 목표와 2pt 넘게 다르면 위치만 1회 더 쓴다
        if !FrameTolerance.isSame(CGRect(origin: .zero, size: after.size), CGRect(origin: .zero, size: target.size)) {
            let corrected = correct(target, actualSize: after.size, placement: placement, in: visible)
            if !FrameTolerance.isSame(CGRect(origin: corrected.origin, size: after.size), after) {
                switch window.setPosition(corrected.origin) {
                case .success:
                    // ⑧ 최종 실제 프레임. 창 사라짐 외의 읽기 실패면 마지막으로 읽은 값을 쓴다.
                    switch window.readFrame() {
                    case .success(let frame): after = frame
                    case .failure(.windowGone): return fail(.windowGone)
                    case .failure: break
                    }
                case .failure(.windowGone):
                    return fail(.windowGone)
                case .failure:
                    // 이미 창은 바뀌었으므로 적용으로 본다. after = 보정 전 실제 프레임.
                    break
                }
            }
        }

        // ⑨ 사이클 갱신
        if let placement, placement.usesRatioCycle {
            cycle.record(placement: placement, window: window, frame: after)
        } else {
            cycle.reset()
        }
        // ⑩
        return .applied(before: before, after: after)
    }

    private func correct(_ target: CGRect, actualSize: CGSize, placement: Placement?, in visible: CGRect) -> CGRect {
        if let placement {
            return SizeConstraintAdjuster.adjust(target: target, actualSize: actualSize, placement: placement, in: visible)
        }
        return SizeConstraintAdjuster.fit(target: target, actualSize: actualSize, in: visible)
    }

    /// 9칸 배치는 현재 프레임으로 사이클을 기록하고(같은 키를 다시 누르면 다음 비율), J·F·모니터 이동은 초기화한다.
    private func noChange(_ placement: Placement?, window: W, frame: CGRect) -> PlacementOutcome {
        if let placement, placement.usesRatioCycle {
            cycle.record(placement: placement, window: window, frame: frame)
        } else {
            cycle.reset()
        }
        return .noChange
    }

    /// 실패한 시도를 연속 입력으로 세지 않도록 사이클을 초기화한다.
    private func fail(_ failure: PlacementFailure) -> PlacementOutcome {
        cycle.reset()
        return .failed(failure)
    }
}
