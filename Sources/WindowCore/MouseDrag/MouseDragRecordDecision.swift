import CoreGraphics

/// 조작 종료 시 창 변경 기록 여부 판정.
public enum MouseDragRecordDecision {
    /// 읽기 실패(창 사라짐 포함) → nil, 시작과 2pt 이내 → nil, 그 외 → (시작 프레임, 실제 프레임, 출처).
    public static func make<Window>(
        session: MouseDragSession<Window>,
        readResult: Result<CGRect, WindowOpError>
    ) -> (before: CGRect, after: CGRect, source: WindowChangeSource)? {
        guard case .success(let actual) = readResult else { return nil }
        guard !FrameTolerance.isSame(session.initialFrame, actual) else { return nil }
        return (before: session.initialFrame, after: actual, source: session.action.changeSource)
    }
}
