import CoreGraphics

/// 끝난 창 변경 1건. `id`는 연속 실패 판정용 일련번호다.
public struct UndoEntry<W: Equatable>: Equatable {
    public let window: W
    public let before: CGRect
    public let after: CGRect
    public let id: Int
}

/// 되돌리기/다시하기 명령 1회의 결과.
public enum UndoOutcome<W: Equatable>: Equatable {
    /// 적용됨 (`FrameApplyOutcome.reached`·`.partial` 모두). 기록은 반대쪽 목록으로 옮겨졌다.
    case applied(UndoEntry<W>)
    /// 처리할 기록이 없음 (사라진 창 기록을 모두 건너뛴 경우 포함)
    case nothingToDo
    /// 창이 움직이지 않음. `discarded == true`면 같은 기록이 연속 2번 실패해 그 기록을 버렸다.
    case failed(discarded: Bool)

    public var shouldBeep: Bool {
        if case .applied = self { return false }
        return true
    }
}

/// 앱 전역 되돌리기·다시하기 목록. 메인 스레드에서만 사용한다.
/// 일시정지·제외 앱 판정은 하지 않는다.
public final class UndoHistory<W: Equatable> {
    public private(set) var isApplying = false
    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }
    public var undoCount: Int { undoStack.count }
    public var redoCount: Int { redoStack.count }

    private let capacity: Int
    /// 배열 끝이 맨 위(가장 최근).
    private var undoStack: [UndoEntry<W>] = []
    private var redoStack: [UndoEntry<W>] = []
    private var nextID = 0
    /// 직전 명령에서 `.failed`였던 기록. 같은 기록이 다시 실패하면 버린다.
    private var lastFailedID: Int?

    public init(capacity: Int = 50) {
        precondition(capacity > 0, "UndoHistory capacity must be positive")
        self.capacity = capacity
    }

    /// 기록 유일 입구. 2pt 이내 변화나 적용 중 들어온 기록은 무시한다(다시하기 목록 유지).
    public func record(window: W, before: CGRect, after: CGRect) {
        guard !isApplying, !FrameTolerance.isSame(before, after) else { return }
        undoStack.append(UndoEntry(window: window, before: before, after: after, id: nextID))
        nextID += 1
        if undoStack.count > capacity {
            undoStack.removeFirst(undoStack.count - capacity)
        }
        redoStack.removeAll()
        lastFailedID = nil
    }

    /// 맨 먼저 `finishPending`을 1회 부른 뒤, 되돌리기 목록 맨 위 기록의 `before`를 적용한다.
    public func undo(finishPending: () -> Void = {}, apply: (W, CGRect) -> FrameApplyOutcome) -> UndoOutcome<W> {
        perform(isUndo: true, finishPending: finishPending, apply: apply)
    }

    /// 맨 먼저 `finishPending`을 1회 부른 뒤, 다시하기 목록 맨 위 기록의 `after`를 적용한다.
    public func redo(finishPending: () -> Void = {}, apply: (W, CGRect) -> FrameApplyOutcome) -> UndoOutcome<W> {
        perform(isUndo: false, finishPending: finishPending, apply: apply)
    }

    private func perform(isUndo: Bool, finishPending: () -> Void, apply: (W, CGRect) -> FrameApplyOutcome) -> UndoOutcome<W> {
        // 적용 중이 아닐 때 부르므로 그 안에서 들어온 기록은 정상 기록된다.
        finishPending()

        isApplying = true
        defer { isApplying = false }

        while let entry = isUndo ? undoStack.last : redoStack.last {
            switch apply(entry.window, isUndo ? entry.before : entry.after) {
            case .reached, .partial:
                popTop(isUndo: isUndo)
                if isUndo { redoStack.append(entry) } else { undoStack.append(entry) }
                lastFailedID = nil
                return .applied(entry)
            case .windowGone:
                undoStack.removeAll { $0.window == entry.window }
                redoStack.removeAll { $0.window == entry.window }
                lastFailedID = nil
            case .failed:
                if lastFailedID == entry.id {
                    popTop(isUndo: isUndo)
                    lastFailedID = nil
                    return .failed(discarded: true)
                }
                lastFailedID = entry.id
                return .failed(discarded: false)
            }
        }
        lastFailedID = nil
        return .nothingToDo
    }

    private func popTop(isUndo: Bool) {
        if isUndo { undoStack.removeLast() } else { redoStack.removeLast() }
    }
}
