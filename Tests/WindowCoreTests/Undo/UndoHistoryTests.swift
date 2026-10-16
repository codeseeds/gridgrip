import CoreGraphics
import XCTest
import WindowCore

fileprivate struct UndoFakeWindow: Equatable {
    let id: Int
}

/// 받은 (창, 목표) 호출을 기록하고, 지정한 규칙으로 결과를 돌려주는 가짜 적용기.
fileprivate final class UndoFakeApplier {
    private(set) var calls: [(window: UndoFakeWindow, frame: CGRect)] = []
    private let result: (UndoFakeWindow, CGRect) -> FrameApplyOutcome

    init(_ result: @escaping (UndoFakeWindow, CGRect) -> FrameApplyOutcome) {
        self.result = result
    }

    /// 받은 목표 프레임을 그대로 actual로 돌려준다.
    static func reached() -> UndoFakeApplier {
        UndoFakeApplier { _, target in .reached(actual: target) }
    }

    static func always(_ outcome: FrameApplyOutcome) -> UndoFakeApplier {
        UndoFakeApplier { _, _ in outcome }
    }

    func apply(_ window: UndoFakeWindow, _ frame: CGRect) -> FrameApplyOutcome {
        calls.append((window, frame))
        return result(window, frame)
    }

    var windowIDs: [Int] { calls.map(\.window.id) }
    var frames: [CGRect] { calls.map(\.frame) }
}

final class UndoHistoryTests: XCTestCase {
    private let w1 = UndoFakeWindow(id: 1)
    private let w2 = UndoFakeWindow(id: 2)
    private let a = CGRect(x: 0, y: 0, width: 100, height: 100)
    private let b = CGRect(x: 200, y: 0, width: 100, height: 100)
    private let c = CGRect(x: 400, y: 0, width: 300, height: 300)

    private func undo(_ history: UndoHistory<UndoFakeWindow>, _ applier: UndoFakeApplier) -> UndoOutcome<UndoFakeWindow> {
        history.undo(apply: applier.apply)
    }

    private func redo(_ history: UndoHistory<UndoFakeWindow>, _ applier: UndoFakeApplier) -> UndoOutcome<UndoFakeWindow> {
        history.redo(apply: applier.apply)
    }

    private func appliedWindow(_ outcome: UndoOutcome<UndoFakeWindow>) -> UndoFakeWindow? {
        guard case .applied(let entry) = outcome else { return nil }
        return entry.window
    }

    // MARK: - CRUD (F-0xx)

    func testUndoAppliesBeforeFrame() {
        let history = UndoHistory<UndoFakeWindow>()
        history.record(window: w1, before: a, after: b)
        let applier = UndoFakeApplier.reached()

        let outcome = undo(history, applier)

        XCTAssertEqual(applier.windowIDs, [1])
        XCTAssertEqual(applier.frames, [a])
        guard case .applied(let entry) = outcome else { return XCTFail("expected .applied, got \(outcome)") }
        XCTAssertEqual(entry.window, w1)
        XCTAssertEqual(entry.before, a)
        XCTAssertEqual(entry.after, b)
        XCTAssertEqual(history.undoCount, 0)
        XCTAssertEqual(history.redoCount, 1)
        XCTAssertFalse(history.canUndo)
        XCTAssertTrue(history.canRedo)
    }

    func testRedoAppliesAfterFrame() {
        let history = UndoHistory<UndoFakeWindow>()
        history.record(window: w1, before: a, after: b)
        _ = undo(history, .reached())
        let applier = UndoFakeApplier.reached()

        let outcome = redo(history, applier)

        XCTAssertEqual(applier.windowIDs, [1])
        XCTAssertEqual(applier.frames, [b])
        XCTAssertEqual(appliedWindow(outcome), w1)
        XCTAssertEqual(history.undoCount, 1)
        XCTAssertEqual(history.redoCount, 0)
    }

    func testUndoRedoOnEmpty() {
        let history = UndoHistory<UndoFakeWindow>()
        let applier = UndoFakeApplier.reached()

        XCTAssertEqual(undo(history, applier), .nothingToDo)
        XCTAssertEqual(redo(history, applier), .nothingToDo)
        XCTAssertTrue(applier.calls.isEmpty)
    }

    func testUndoOrderAcrossWindows() {
        let history = UndoHistory<UndoFakeWindow>()
        history.record(window: w1, before: a, after: b)
        history.record(window: w2, before: b, after: c)
        history.record(window: w1, before: b, after: c)
        let applier = UndoFakeApplier.reached()

        for _ in 0..<3 { _ = undo(history, applier) }

        XCTAssertEqual(applier.windowIDs, [1, 2, 1])
        XCTAssertEqual(applier.frames, [b, b, a])
    }

    func testUndoPartialCountsAsApplied() {
        let history = UndoHistory<UndoFakeWindow>()
        history.record(window: w1, before: a, after: c)

        let outcome = undo(history, .always(.partial(actual: CGRect(x: 0, y: 0, width: 300, height: 300))))

        XCTAssertEqual(appliedWindow(outcome), w1)
        XCTAssertEqual(history.undoCount, 0)
        XCTAssertEqual(history.redoCount, 1)
    }

    func testRedoPartialCountsAsApplied() {
        let history = UndoHistory<UndoFakeWindow>()
        history.record(window: w1, before: a, after: c)
        _ = undo(history, .reached())

        let outcome = redo(history, .always(.partial(actual: CGRect(x: 400, y: 0, width: 100, height: 100))))

        XCTAssertEqual(appliedWindow(outcome), w1)
        XCTAssertEqual(history.undoCount, 1)
        XCTAssertEqual(history.redoCount, 0)
    }

    // MARK: - Validation (F-1xx)

    func testCapacityDropsOldest() {
        let history = UndoHistory<UndoFakeWindow>()
        for i in 1...51 {
            history.record(window: UndoFakeWindow(id: i), before: a, after: b)
        }
        XCTAssertEqual(history.undoCount, 50)

        let applier = UndoFakeApplier.reached()
        for _ in 0..<50 { _ = undo(history, applier) }

        XCTAssertEqual(applier.windowIDs, Array((2...51).reversed()))
        XCTAssertEqual(undo(history, applier), .nothingToDo)
    }

    func testCustomCapacity() {
        let history = UndoHistory<UndoFakeWindow>(capacity: 3)
        for i in 1...5 {
            history.record(window: UndoFakeWindow(id: i), before: a, after: b)
        }
        XCTAssertEqual(history.undoCount, 3)
    }

    func testNoOpRecordIgnored() {
        let history = UndoHistory<UndoFakeWindow>()
        history.record(window: w1, before: a, after: a)
        XCTAssertEqual(history.undoCount, 0)
        XCTAssertFalse(history.canUndo)
    }

    func testWithinToleranceKeepsRedo() {
        let history = UndoHistory<UndoFakeWindow>()
        history.record(window: w1, before: a, after: b)
        _ = undo(history, .reached())

        history.record(window: w1, before: a, after: CGRect(x: 1.5, y: 0, width: 98, height: 100))

        XCTAssertEqual(history.undoCount, 0)
        XCTAssertEqual(history.redoCount, 1)
        let applier = UndoFakeApplier.reached()
        _ = redo(history, applier)
        XCTAssertEqual(applier.windowIDs, [1])
        XCTAssertEqual(applier.frames, [b])
    }

    func testBeyondToleranceRecords() {
        let history = UndoHistory<UndoFakeWindow>()
        history.record(window: w1, before: a, after: b)
        _ = undo(history, .reached())

        history.record(window: w1, before: a, after: CGRect(x: 2.5, y: 0, width: 100, height: 100))

        XCTAssertEqual(history.undoCount, 1)
        XCTAssertEqual(history.redoCount, 0)
        XCTAssertFalse(history.canRedo)
    }

    // MARK: - Error Handling (F-3xx)

    func testUndoSkipsGoneWindow() {
        let history = UndoHistory<UndoFakeWindow>()
        history.record(window: w1, before: a, after: b)
        history.record(window: w2, before: a, after: c)
        history.record(window: w2, before: c, after: b)
        let applier = UndoFakeApplier { window, target in
            window.id == 2 ? .windowGone : .reached(actual: target)
        }

        let outcome = undo(history, applier)

        XCTAssertEqual(applier.windowIDs, [2, 1])
        XCTAssertEqual(applier.frames, [c, a])
        XCTAssertEqual(appliedWindow(outcome), w1)
        XCTAssertEqual(history.undoCount, 0)
        XCTAssertEqual(history.redoCount, 1)
        let redoApplier = UndoFakeApplier.reached()
        _ = redo(history, redoApplier)
        XCTAssertEqual(redoApplier.windowIDs, [1])
    }

    func testUndoAllGone() {
        let history = UndoHistory<UndoFakeWindow>()
        history.record(window: w1, before: a, after: b)

        XCTAssertEqual(undo(history, .always(.windowGone)), .nothingToDo)
        XCTAssertEqual(history.undoCount, 0)
        XCTAssertEqual(history.redoCount, 0)
    }

    func testRedoSkipsGoneWindow() {
        let history = UndoHistory<UndoFakeWindow>()
        history.record(window: w1, before: a, after: b)
        history.record(window: w2, before: a, after: c)
        history.record(window: w1, before: b, after: c)
        for _ in 0..<3 { _ = undo(history, .reached()) }
        let applier = UndoFakeApplier { window, target in
            window.id == 1 ? .windowGone : .reached(actual: target)
        }

        let outcome = redo(history, applier)

        XCTAssertEqual(applier.windowIDs, [1, 2])
        XCTAssertEqual(applier.frames, [b, c])
        XCTAssertEqual(appliedWindow(outcome), w2)
        XCTAssertEqual(history.redoCount, 0)
        XCTAssertEqual(history.undoCount, 1)
    }

    func testUndoFailedOnceKeepsEntry() {
        let history = UndoHistory<UndoFakeWindow>()
        history.record(window: w1, before: a, after: b)

        let outcome = undo(history, .always(.failed(nil)))

        XCTAssertEqual(outcome, .failed(discarded: false))
        XCTAssertTrue(outcome.shouldBeep)
        XCTAssertEqual(history.undoCount, 1)
        XCTAssertEqual(history.redoCount, 0)

        let applier = UndoFakeApplier.reached()
        let retry = undo(history, applier)
        XCTAssertEqual(applier.windowIDs, [1])
        XCTAssertEqual(applier.frames, [a])
        XCTAssertEqual(appliedWindow(retry), w1)
    }

    func testRedoFailedOnceKeepsEntry() {
        let history = UndoHistory<UndoFakeWindow>()
        history.record(window: w1, before: a, after: b)
        _ = undo(history, .reached())

        let outcome = redo(history, .always(.failed(nil)))

        XCTAssertEqual(outcome, .failed(discarded: false))
        XCTAssertEqual(history.undoCount, 0)
        XCTAssertEqual(history.redoCount, 1)
        XCTAssertTrue(history.canRedo)
    }

    func testUndoFailedTwiceDiscardsOnlyThatEntry() {
        let history = UndoHistory<UndoFakeWindow>()
        history.record(window: w1, before: a, after: b)
        history.record(window: w2, before: a, after: c)

        XCTAssertEqual(undo(history, .always(.failed(nil))), .failed(discarded: false))
        let second = UndoFakeApplier.always(.failed(nil))
        XCTAssertEqual(undo(history, second), .failed(discarded: true))
        XCTAssertEqual(second.windowIDs, [2])
        XCTAssertEqual(second.frames, [a])
        XCTAssertEqual(history.undoCount, 1)

        let applier = UndoFakeApplier.reached()
        _ = undo(history, applier)
        XCTAssertEqual(applier.windowIDs, [1])
        XCTAssertEqual(applier.frames, [a])
    }

    func testRedoFailedTwiceDiscards() {
        let history = UndoHistory<UndoFakeWindow>()
        history.record(window: w1, before: a, after: b)
        _ = undo(history, .reached())

        XCTAssertEqual(redo(history, .always(.failed(nil))), .failed(discarded: false))
        XCTAssertEqual(redo(history, .always(.failed(nil))), .failed(discarded: true))
        XCTAssertEqual(history.redoCount, 0)
        XCTAssertEqual(history.undoCount, 0)
    }

    func testFailureStreakResetBySuccess() {
        let history = UndoHistory<UndoFakeWindow>()
        history.record(window: w1, before: a, after: b)
        _ = undo(history, .always(.failed(nil)))
        _ = undo(history, .reached())

        XCTAssertEqual(redo(history, .always(.failed(nil))), .failed(discarded: false))
        XCTAssertEqual(history.redoCount, 1)
    }

    func testFailureStreakResetByNewRecord() {
        let history = UndoHistory<UndoFakeWindow>()
        history.record(window: w1, before: a, after: b)
        _ = undo(history, .always(.failed(nil)))
        history.record(window: w2, before: a, after: c)
        _ = undo(history, .reached())

        XCTAssertEqual(undo(history, .always(.failed(nil))), .failed(discarded: false))
        XCTAssertEqual(history.undoCount, 1)
    }

    func testGoneSkipThenFailedStartsNewStreak() {
        let history = UndoHistory<UndoFakeWindow>()
        history.record(window: w1, before: a, after: b)
        history.record(window: w2, before: a, after: c)
        let applier = UndoFakeApplier { window, _ in window.id == 2 ? .windowGone : .failed(nil) }

        XCTAssertEqual(undo(history, applier), .failed(discarded: false))
        XCTAssertEqual(applier.windowIDs, [2, 1])
        XCTAssertEqual(history.undoCount, 1)

        XCTAssertEqual(undo(history, .always(.failed(nil))), .failed(discarded: true))
        XCTAssertEqual(history.undoCount, 0)
    }

    func testFailureStreakResetByNothingToDo() {
        let history = UndoHistory<UndoFakeWindow>()
        history.record(window: w1, before: a, after: b)
        _ = undo(history, .always(.failed(nil)))  // w1 실패 1회째
        XCTAssertEqual(redo(history, .reached()), .nothingToDo)

        XCTAssertEqual(undo(history, .always(.failed(nil))), .failed(discarded: false))
        XCTAssertEqual(history.undoCount, 1)
    }

    func testFailureStreakResetByOtherEntryFailure() {
        let history = UndoHistory<UndoFakeWindow>()
        history.record(window: w1, before: a, after: b)
        history.record(window: w2, before: a, after: c)
        _ = undo(history, .reached())              // w2 → 다시하기 목록
        _ = undo(history, .always(.failed(nil)))   // w1 실패 1회째
        _ = redo(history, .always(.failed(nil)))   // w2 실패 1회째 (다른 기록)

        XCTAssertEqual(undo(history, .always(.failed(nil))), .failed(discarded: false))
        XCTAssertEqual(history.undoCount, 1)
    }

    // MARK: - Business Logic (F-4xx)

    func testRepeatedPlacementEachRecorded() {
        let history = UndoHistory<UndoFakeWindow>()
        let o = a
        let p1 = CGRect(x: 0, y: 0, width: 300, height: 900)
        let p2 = CGRect(x: 0, y: 0, width: 450, height: 900)
        let p3 = CGRect(x: 0, y: 0, width: 675, height: 900)
        history.record(window: w1, before: o, after: p1)
        history.record(window: w1, before: p1, after: p2)
        history.record(window: w1, before: p2, after: p3)
        XCTAssertEqual(history.undoCount, 3)

        let applier = UndoFakeApplier.reached()
        for _ in 0..<3 { _ = undo(history, applier) }
        XCTAssertEqual(applier.frames, [p2, p1, o])
    }

    func testNewRecordClearsRedo() {
        let history = UndoHistory<UndoFakeWindow>()
        history.record(window: w1, before: a, after: b)
        history.record(window: w1, before: b, after: c)
        _ = undo(history, .reached())
        _ = undo(history, .reached())

        history.record(window: w2, before: a, after: b)

        XCTAssertEqual(history.redoCount, 0)
        XCTAssertFalse(history.canRedo)
        XCTAssertEqual(redo(history, .reached()), .nothingToDo)
    }

    func testRecordDuringUndoApplyIgnored() {
        let history = UndoHistory<UndoFakeWindow>()
        history.record(window: w1, before: a, after: b)
        var applyingInside: Bool?

        _ = history.undo(apply: { [b, a, w1] _, target in
            applyingInside = history.isApplying
            history.record(window: w1, before: b, after: a)
            return .reached(actual: target)
        })

        XCTAssertEqual(applyingInside, true)
        XCTAssertFalse(history.isApplying)
        XCTAssertEqual(history.undoCount, 0)
        XCTAssertEqual(history.redoCount, 1)
    }

    func testRecordDuringRedoApplyIgnored() {
        let history = UndoHistory<UndoFakeWindow>()
        history.record(window: w1, before: a, after: b)
        _ = undo(history, .reached())

        _ = history.redo(apply: { [a, c, w2] _, target in
            history.record(window: w2, before: a, after: c)
            return .reached(actual: target)
        })

        XCTAssertEqual(history.undoCount, 1)
        XCTAssertEqual(history.redoCount, 0)
        let applier = UndoFakeApplier.reached()
        _ = undo(history, applier)
        XCTAssertEqual(applier.windowIDs, [1])
    }

    func testUndoFinishesPendingFirst() {
        let history = UndoHistory<UndoFakeWindow>()
        history.record(window: w1, before: a, after: b)
        var order: [String] = []
        var finishCount = 0
        var applied: [(UndoFakeWindow, CGRect)] = []

        let outcome = history.undo(
            finishPending: { [a, c, w2] in
                order.append("finish")
                finishCount += 1
                history.record(window: w2, before: a, after: c)
            },
            apply: { window, target in
                order.append("apply")
                applied.append((window, target))
                return .reached(actual: target)
            }
        )

        XCTAssertEqual(order, ["finish", "apply"])
        XCTAssertEqual(finishCount, 1)
        XCTAssertEqual(applied.map(\.0), [w2])
        XCTAssertEqual(applied.map(\.1), [a])
        XCTAssertEqual(appliedWindow(outcome), w2)
        XCTAssertEqual(history.undoCount, 1)
        XCTAssertEqual(history.redoCount, 1)
    }

    func testUndoOnEmptyUsesFinishedPendingRecord() {
        let history = UndoHistory<UndoFakeWindow>()
        let applier = UndoFakeApplier.reached()

        let outcome = history.undo(
            finishPending: { [a, b, w1] in history.record(window: w1, before: a, after: b) },
            apply: applier.apply
        )

        XCTAssertEqual(appliedWindow(outcome), w1)
        XCTAssertEqual(applier.windowIDs, [1])
        XCTAssertEqual(applier.frames, [a])
    }

    func testRedoAfterPendingRecordClearsRedo() {
        let history = UndoHistory<UndoFakeWindow>()
        history.record(window: w1, before: a, after: b)
        _ = undo(history, .reached())
        let applier = UndoFakeApplier.reached()

        let outcome = history.redo(
            finishPending: { [a, c, w2] in history.record(window: w2, before: a, after: c) },
            apply: applier.apply
        )

        XCTAssertEqual(outcome, .nothingToDo)
        XCTAssertTrue(applier.calls.isEmpty)
        XCTAssertEqual(history.undoCount, 1)
        XCTAssertEqual(history.redoCount, 0)
    }

    func testFinishPendingCalledOncePerCommand() {
        var counter = 0
        let empty = UndoHistory<UndoFakeWindow>()
        XCTAssertEqual(empty.undo(finishPending: { counter += 1 }, apply: UndoFakeApplier.reached().apply), .nothingToDo)
        XCTAssertEqual(counter, 1)

        let history = UndoHistory<UndoFakeWindow>()
        history.record(window: w1, before: a, after: b)
        history.record(window: w2, before: a, after: c)
        let applier = UndoFakeApplier { window, target in
            window.id == 2 ? .windowGone : .reached(actual: target)
        }
        _ = history.undo(finishPending: { counter += 1 }, apply: applier.apply)

        XCTAssertEqual(counter, 2)
        XCTAssertEqual(applier.calls.count, 2)
    }

    func testCanUndoCanRedoTransitions() {
        let history = UndoHistory<UndoFakeWindow>()
        func state() -> [Bool] { [history.canUndo, history.canRedo] }

        XCTAssertEqual(state(), [false, false])
        history.record(window: w1, before: a, after: b)
        XCTAssertEqual(state(), [true, false])
        _ = undo(history, .reached())
        XCTAssertEqual(state(), [false, true])
        _ = redo(history, .reached())
        XCTAssertEqual(state(), [true, false])
        _ = undo(history, .always(.windowGone))
        XCTAssertEqual(state(), [false, false])
    }

    func testShouldBeepMapping() {
        let history = UndoHistory<UndoFakeWindow>()
        history.record(window: w1, before: a, after: b)
        let applied = undo(history, .reached())
        guard case .applied = applied else { return XCTFail("expected .applied, got \(applied)") }

        XCTAssertFalse(applied.shouldBeep)
        XCTAssertTrue(UndoOutcome<UndoFakeWindow>.nothingToDo.shouldBeep)
        XCTAssertTrue(UndoOutcome<UndoFakeWindow>.failed(discarded: false).shouldBeep)
        XCTAssertTrue(UndoOutcome<UndoFakeWindow>.failed(discarded: true).shouldBeep)
    }
}
