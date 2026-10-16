import AppKit
import CoreGraphics
import os
import WindowCore

/// 창 변경 통로에서 끝난 변경을 받아 쌓고, 단축키·메뉴 명령으로 되돌리거나 다시 적용한다.
/// AX 호출은 메인 스레드에서 동기로 한다(대기 한도 0.25초는 `AXWindowElement`가 설정). 일시정지는 디스패처가 이미 거른다.
@MainActor
final class UndoController: WindowChangeRecorder {
    private let windowChanges: WindowChangeHub
    private let history = UndoHistory<AXWindowElement>()
    private let logger = Logger(subsystem: AppIdentity.bundleIdentifier, category: "undo")

    init(windowChanges: WindowChangeHub) {
        self.windowChanges = windowChanges
    }

    var canUndo: Bool { history.canUndo }
    var canRedo: Bool { history.canRedo }

    /// `WindowChangeRecorder`는 스레드 제한이 없는 프로토콜이라 `nonisolated`로 받는다.
    /// 허브가 메인 스레드에서만 부르므로 메인 액터로 간주해 기록한다. 출처와 무관하게 기록한다.
    nonisolated func windowDidChange(_ window: AXWindowElement, before: CGRect, after: CGRect, source: WindowChangeSource) {
        MainActor.assumeIsolated {
            history.record(window: window, before: before, after: after)
        }
    }

    func performUndo() {
        perform("undo") { finishPending, apply in history.undo(finishPending: finishPending, apply: apply) }
    }

    func performRedo() {
        perform("redo") { finishPending, apply in history.redo(finishPending: finishPending, apply: apply) }
    }

    private func perform(
        _ name: String,
        _ command: (() -> Void, (AXWindowElement, CGRect) -> FrameApplyOutcome) -> UndoOutcome<AXWindowElement>
    ) {
        // UndoOutcome은 부분 적용·사라진 창 폐기를 구분하지 않으므로 적용 결과를 따로 모아 로그에 쓴다.
        var applyResults: [FrameApplyOutcome] = []
        let outcome = command(
            { windowChanges.finishPendingOperations() },
            { window, target in
                let result = FrameWriter.apply(target, to: window)
                applyResults.append(result)
                return result
            }
        )
        log(name, outcome, applyResults)
        if outcome.shouldBeep {
            NSSound.beep()
        }
    }

    private func log(_ name: String, _ outcome: UndoOutcome<AXWindowElement>, _ applyResults: [FrameApplyOutcome]) {
        let goneCount = applyResults.filter { $0 == .windowGone }.count
        if goneCount > 0 {
            logger.info("\(name, privacy: .public): windowGone discarded \(goneCount, privacy: .public) window(s)")
        }
        switch outcome {
        case .applied(let entry):
            let kind: String
            if case .partial = applyResults.last { kind = "partial" } else { kind = "applied" }
            logger.debug("\(name, privacy: .public): \(kind, privacy: .public) before=\(String(describing: entry.before), privacy: .private) after=\(String(describing: entry.after), privacy: .private)")
        case .nothingToDo:
            logger.debug("\(name, privacy: .public): nothingToDo")
        case .failed(let discarded):
            let error = applyResults.last.map { String(describing: $0) } ?? "-"
            logger.notice("\(name, privacy: .public): \(discarded ? "discarded" : "failed", privacy: .public) \(error, privacy: .public)")
        }
    }
}
