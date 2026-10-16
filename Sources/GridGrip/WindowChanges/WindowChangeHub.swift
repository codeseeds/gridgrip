import CoreGraphics
import WindowCore

/// 끝난 창 변경 1건을 받는 쪽(`UndoController`).
protocol WindowChangeRecorder: AnyObject {
    func windowDidChange(_ window: AXWindowElement, before: CGRect, after: CGRect, source: WindowChangeSource)
}

/// 창 변경 기록 통로. 형태는 항상 "끝난 변경 1건 = (창, before, after, source)".
@MainActor
final class WindowChangeHub {
    /// 되돌리기 기능이 installUndo에서 연결한다. 그 전엔 nil(기록 안 함).
    weak var recorder: WindowChangeRecorder?
    private var finishers: [() -> Void] = []

    /// `FrameTolerance.isSame(before, after)`면 무시. 로그는 호출측이 남긴다.
    func record(_ window: AXWindowElement, before: CGRect, after: CGRect, source: WindowChangeSource) {
        guard !FrameTolerance.isSame(before, after) else { return }
        recorder?.windowDidChange(window, before: before, after: after, source: source)
    }

    /// 진행 중 조작을 즉시 끝내는 함수 등록(마우스 조작 기능이 1개 등록).
    func addPendingOperationFinisher(_ finish: @escaping () -> Void) {
        finishers.append(finish)
    }

    /// 등록된 모든 마무리 함수를 등록 순서대로 동기 호출. 반환 시점엔 진행 중 조작의 기록이 이미 끝나 있다.
    func finishPendingOperations() {
        finishers.forEach { $0() }
    }
}
