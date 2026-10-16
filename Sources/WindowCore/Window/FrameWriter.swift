import CoreGraphics

/// 프레임 쓰기 결과. 개별 set 호출이 아니라 **다시 읽은 실제 프레임**으로 판정한다.
public enum FrameApplyOutcome: Equatable {
    /// 다시 읽은 실제 프레임이 목표와 2pt 이내
    case reached(actual: CGRect)
    /// 목표엔 못 갔지만 쓰기 전 프레임과 2pt 넘게 달라짐(일부 적용)
    case partial(actual: CGRect)
    case windowGone
    /// 실제 프레임이 쓰기 전과 같음(아무것도 안 바뀜). 값은 마지막 쓰기 오류(없으면 nil) 또는 읽기 오류
    case failed(WindowOpError?)
}

/// 목표 프레임 1건 적용. 키보드 배치·되돌리기가 공통으로 쓴다.
/// 마우스 조작 경로는 이벤트마다 위치나 크기 하나만 쓰므로 이 타입을 쓰지 않는다.
public enum FrameWriter {
    /// 순서: 쓰기 전 프레임 읽기 → 크기 → 위치 → 크기 → 실제 프레임 다시 읽기 → 분류.
    /// `canResize == false`면 크기 쓰기를 생략한다. 쓰기가 `.windowGone`/`.timedOut`이면 남은 쓰기를 생략하고
    /// 곧바로 다시 읽는다(응답 없는 앱에서 대기 한도가 겹겹이 쌓이지 않게).
    public static func apply(_ target: CGRect, to window: FrameWritable, canResize: Bool = true) -> FrameApplyOutcome {
        let before: CGRect
        switch window.readFrame() {
        case .success(let frame):
            before = frame
        case .failure(.windowGone):
            return .windowGone
        case .failure(let error):
            return .failed(error)
        }

        let setSize = { window.setSize(target.size) }
        let setPosition = { window.setPosition(target.origin) }
        let writes = canResize ? [setSize, setPosition, setSize] : [setPosition]

        var lastError: WindowOpError?
        for write in writes {
            guard case .failure(let error) = write() else { continue }
            lastError = error
            if error == .windowGone || error == .timedOut { break }
        }

        switch window.readFrame() {
        case .success(let actual):
            if FrameTolerance.isSame(actual, target) { return .reached(actual: actual) }
            if !FrameTolerance.isSame(actual, before) { return .partial(actual: actual) }
            return .failed(lastError)
        case .failure(.windowGone):
            return .windowGone
        case .failure(let error):
            return .failed(error)
        }
    }
}
