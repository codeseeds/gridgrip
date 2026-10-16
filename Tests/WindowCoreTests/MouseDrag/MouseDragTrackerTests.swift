import CoreGraphics
import XCTest
import WindowCore

/// 공통 픽스처: 창 = 정수 ID(W1 = 1), 기본 설정, 창 프레임 (100,200,800,600), 잡기 위치 (500,500).
final class MouseDragTrackerTests: XCTestCase {
    private typealias Tracker = MouseDragTracker<Int>

    private let moveFlags: UInt64 = 0x840000
    private let resizeFlags: UInt64 = 0x880000
    private let frame = CGRect(x: 100, y: 200, width: 800, height: 600)
    private let grabPoint = CGPoint(x: 500, y: 500)
    private var settings = MouseDragSettings.default

    private func moved(
        _ tracker: inout Tracker,
        flags: UInt64,
        at location: CGPoint,
        delta: CGVector = .zero,
        time: TimeInterval = 0,
        paused: Bool = false
    ) -> MouseDragStep<Int> {
        tracker.handleMouseMoved(flags: flags, location: location, delta: delta, timestamp: time, isPaused: paused, settings: settings)
    }

    /// 대기 상태에서 잡기 요청 → 잡기 성공까지 진행한다.
    private func grabbed(_ flags: UInt64? = nil, at location: CGPoint? = nil, window: Int = 1) -> Tracker {
        var tracker = Tracker()
        let point = location ?? grabPoint
        let step = moved(&tracker, flags: flags ?? moveFlags, at: point)
        guard case .grab = step.command else {
            XCTFail("잡기 요청이 나오지 않음: \(step.command)")
            return tracker
        }
        tracker.didGrab(window: window, frame: frame)
        return tracker
    }

    private var w1Move: MouseDragSession<Int> { MouseDragSession(window: 1, action: .move, initialFrame: frame) }

    // MARK: - mouseMoved

    func testIdleNonMatchingPassesThrough() {
        var tracker = Tracker()
        let step = moved(&tracker, flags: 0, at: grabPoint, delta: CGVector(dx: 5, dy: 5))
        XCTAssertEqual(step.command, .passThrough)
        XCTAssertNil(step.endedSession)
    }

    func testFirstMatchingEventRequestsGrabWithoutMoving() {
        var tracker = Tracker()
        let step = moved(&tracker, flags: moveFlags, at: grabPoint, delta: CGVector(dx: 7, dy: 3))
        XCTAssertEqual(step.command, .grab(.move))
        XCTAssertNil(step.endedSession)
        tracker.didGrab(window: 1, frame: frame)
        XCTAssertTrue(tracker.isActive)
    }

    func testMoveAccumulatesDeltas() {
        var tracker = grabbed()
        XCTAssertEqual(moved(&tracker, flags: moveFlags, at: CGPoint(x: 510, y: 500), delta: CGVector(dx: 10, dy: 0)).command,
                       .apply(window: 1, target: .position(CGPoint(x: 110, y: 200))))
        XCTAssertEqual(moved(&tracker, flags: moveFlags, at: CGPoint(x: 515, y: 480), delta: CGVector(dx: 5, dy: -20)).command,
                       .apply(window: 1, target: .position(CGPoint(x: 115, y: 180))))
        XCTAssertEqual(moved(&tracker, flags: moveFlags, at: CGPoint(x: 512, y: 484), delta: CGVector(dx: -3, dy: 4)).command,
                       .apply(window: 1, target: .position(CGPoint(x: 112, y: 184))))
    }

    func testResizeAccumulatesDeltasKeepingOrigin() {
        var tracker = grabbed(resizeFlags)
        let first = moved(&tracker, flags: resizeFlags, at: CGPoint(x: 550, y: 530), delta: CGVector(dx: 50, dy: 30))
        let second = moved(&tracker, flags: resizeFlags, at: CGPoint(x: 530, y: 540), delta: CGVector(dx: -20, dy: 10))
        XCTAssertEqual(first.command, .apply(window: 1, target: .size(CGSize(width: 850, height: 630))))
        XCTAssertEqual(second.command, .apply(window: 1, target: .size(CGSize(width: 830, height: 640))))
    }

    func testResizeClampsToMinimumWithoutLosingDelta() {
        XCTAssertEqual(MouseDragGeometry.minimumSize, CGSize(width: 120, height: 80))
        var tracker = grabbed(resizeFlags)
        let shrink = moved(&tracker, flags: resizeFlags, at: CGPoint(x: 10, y: 10), delta: CGVector(dx: -750, dy: -560))
        XCTAssertEqual(shrink.command, .apply(window: 1, target: .size(CGSize(width: 120, height: 80))))
        let grow = moved(&tracker, flags: resizeFlags, at: CGPoint(x: 110, y: 110), delta: CGVector(dx: 100, dy: 100))
        XCTAssertEqual(grow.command, .apply(window: 1, target: .size(CGSize(width: 150, height: 140))))
    }

    func testDeltaIgnoredOnAxisWhereCursorDidNotMove() {
        var tracker = grabbed(at: CGPoint(x: 500, y: 0))
        let step = moved(&tracker, flags: moveFlags, at: CGPoint(x: 510, y: 0), delta: CGVector(dx: 10, dy: -15))
        XCTAssertEqual(step.command, .apply(window: 1, target: .position(CGPoint(x: 110, y: 200))))
    }

    func testZeroDeltaSwallowsWithoutCommand() {
        var tracker = grabbed()
        XCTAssertEqual(moved(&tracker, flags: moveFlags, at: CGPoint(x: 501, y: 501), delta: .zero).command, .swallow)
        XCTAssertEqual(moved(&tracker, flags: moveFlags, at: CGPoint(x: 501, y: 501), delta: CGVector(dx: 3, dy: 3)).command, .swallow)
    }

    func testReleaseOnMouseMovedEndsSession() {
        var tracker = grabbed()
        _ = moved(&tracker, flags: moveFlags, at: CGPoint(x: 510, y: 510), delta: CGVector(dx: 10, dy: 10))
        let step = moved(&tracker, flags: 0, at: CGPoint(x: 520, y: 520), delta: CGVector(dx: 10, dy: 10))
        XCTAssertEqual(step.command, .passThrough)
        XCTAssertEqual(step.endedSession, w1Move)
        XCTAssertFalse(tracker.isActive)
        XCTAssertEqual(moved(&tracker, flags: moveFlags, at: grabPoint).command, .grab(.move))
    }

    func testReleaseWithoutMovementStillReturnsSession() {
        var tracker = grabbed()
        let step = moved(&tracker, flags: 0, at: grabPoint)
        XCTAssertNotNil(step.endedSession)
        XCTAssertEqual(step.endedSession?.initialFrame, frame)
    }

    func testSwitchingActionOnMouseMovedEndsAndRegrabs() {
        var tracker = grabbed()
        _ = moved(&tracker, flags: moveFlags, at: CGPoint(x: 510, y: 500), delta: CGVector(dx: 10, dy: 0))
        let step = moved(&tracker, flags: resizeFlags, at: CGPoint(x: 520, y: 500), delta: CGVector(dx: 10, dy: 0))
        XCTAssertEqual(step.endedSession?.action, .move)
        XCTAssertEqual(step.command, .grab(.resize))
    }

    func testPausedEndsSessionAndPassesThrough() {
        var active = grabbed()
        let activeStep = moved(&active, flags: moveFlags, at: CGPoint(x: 510, y: 500), delta: CGVector(dx: 10, dy: 0), paused: true)
        XCTAssertNotNil(activeStep.endedSession)
        XCTAssertEqual(activeStep.command, .passThrough)

        var idle = Tracker()
        XCTAssertEqual(moved(&idle, flags: moveFlags, at: grabPoint, paused: true).command, .passThrough)

        var suppressed = Tracker()
        _ = moved(&suppressed, flags: moveFlags, at: grabPoint)
        suppressed.grabFailed(.noWindow, location: grabPoint, timestamp: 0)
        XCTAssertEqual(moved(&suppressed, flags: moveFlags, at: CGPoint(x: 900, y: 900), time: 5, paused: true).command, .passThrough)
    }

    func testSettingsChangeAppliesOnNextEvent() {
        var tracker = Tracker()
        settings = MouseDragSettings(moveModifiers: [.command], resizeModifiers: [.fn, .option], bringWindowToFront: true)
        XCTAssertEqual(moved(&tracker, flags: 0x100000, at: grabPoint).command, .grab(.move))
        XCTAssertEqual(moved(&tracker, flags: moveFlags, at: grabPoint).command, .passThrough)
    }

    // MARK: - 잡기 실패·억제

    func testGrabFailureSuppressesRetryNearbyAndSoon() {
        var tracker = Tracker()
        XCTAssertEqual(moved(&tracker, flags: moveFlags, at: grabPoint, time: 0).command, .grab(.move))
        tracker.grabFailed(.noWindow, location: grabPoint, timestamp: 0)
        let events: [(CGPoint, TimeInterval)] = [(CGPoint(x: 520, y: 500), 1.0), (CGPoint(x: 500, y: 500), 0.1), (CGPoint(x: 560, y: 500), 0.2)]
        for (location, time) in events {
            let step = moved(&tracker, flags: moveFlags, at: location, time: time)
            XCTAssertEqual(step.command, .passThrough, "\(location) t=\(time)")
            XCTAssertNil(step.endedSession)
        }
    }

    func testSuppressedRetriesAfterDistanceAndInterval() {
        for reason in [MouseGrabFailure.noWindow, .excluded, .readFailed] {
            var tracker = Tracker()
            _ = moved(&tracker, flags: moveFlags, at: grabPoint, time: 0)
            tracker.grabFailed(reason, location: grabPoint, timestamp: 0)
            _ = moved(&tracker, flags: moveFlags, at: CGPoint(x: 520, y: 500), time: 1.0)
            XCTAssertEqual(moved(&tracker, flags: moveFlags, at: CGPoint(x: 540, y: 500), time: 0.3).command, .grab(.move), "\(reason)")
        }
    }

    func testTimedOutSuppressesUntilModifiersChange() {
        var tracker = Tracker()
        _ = moved(&tracker, flags: moveFlags, at: grabPoint, time: 0)
        tracker.grabFailed(.timedOut, location: grabPoint, timestamp: 0)
        XCTAssertEqual(moved(&tracker, flags: moveFlags, at: CGPoint(x: 900, y: 900), time: 5.0).command, .passThrough)
        XCTAssertNil(tracker.handleFlagsChanged(flags: 0, isPaused: false, settings: settings))
        XCTAssertEqual(moved(&tracker, flags: moveFlags, at: CGPoint(x: 900, y: 900), time: 5.1).command, .grab(.move))
    }

    func testSuppressionClearsWhenActionChanges() {
        var tracker = Tracker()
        _ = moved(&tracker, flags: moveFlags, at: grabPoint, time: 0)
        tracker.grabFailed(.noWindow, location: grabPoint, timestamp: 0)
        XCTAssertEqual(moved(&tracker, flags: resizeFlags, at: grabPoint, time: 0).command, .grab(.resize))
    }

    func testWindowDisappearedEndsWithoutSessionAndSuppresses() {
        var tracker = grabbed()
        var ended: [MouseDragSession<Int>] = []
        let first = moved(&tracker, flags: moveFlags, at: CGPoint(x: 510, y: 500), delta: CGVector(dx: 10, dy: 0), time: 0)
        ended += [first.endedSession].compactMap { $0 }

        tracker.windowDisappeared(2)
        let afterOther = moved(&tracker, flags: moveFlags, at: CGPoint(x: 520, y: 500), delta: CGVector(dx: 10, dy: 0), time: 0.1)
        XCTAssertEqual(afterOther.command, .apply(window: 1, target: .position(CGPoint(x: 120, y: 200))))
        ended += [afterOther.endedSession].compactMap { $0 }

        tracker.windowDisappeared(1)
        let afterGone = moved(&tracker, flags: moveFlags, at: CGPoint(x: 620, y: 500), delta: CGVector(dx: 100, dy: 0), time: 1.1)
        XCTAssertEqual(afterGone.command, .passThrough)
        ended += [afterGone.endedSession].compactMap { $0 }
        XCTAssertTrue(ended.isEmpty)
        XCTAssertNil(tracker.endActive())

        XCTAssertNil(tracker.handleFlagsChanged(flags: 0, isPaused: false, settings: settings))
        XCTAssertEqual(moved(&tracker, flags: moveFlags, at: CGPoint(x: 620, y: 500), time: 1.2).command, .grab(.move))
    }

    func testEndActiveReturnsSessionOnlyWhenActive() {
        var active = grabbed()
        XCTAssertEqual(active.endActive(), w1Move)
        XCTAssertEqual(moved(&active, flags: moveFlags, at: grabPoint).command, .grab(.move))

        var idle = Tracker()
        XCTAssertNil(idle.endActive())

        var suppressed = Tracker()
        _ = moved(&suppressed, flags: moveFlags, at: grabPoint)
        suppressed.grabFailed(.noWindow, location: grabPoint, timestamp: 0)
        XCTAssertNil(suppressed.endActive())
    }

    func testHandleWhileAwaitingGrabPassesThroughWithoutRegrab() {
        var tracker = Tracker()
        XCTAssertEqual(moved(&tracker, flags: moveFlags, at: grabPoint).command, .grab(.move))
        let pending = moved(&tracker, flags: moveFlags, at: CGPoint(x: 505, y: 500), delta: CGVector(dx: 5, dy: 0))
        XCTAssertEqual(pending.command, .passThrough)
        XCTAssertNil(pending.endedSession)
        XCTAssertTrue(tracker.isAwaitingGrab)
        // 다른 조작 조합이 되면 새 잡기 요청
        XCTAssertEqual(moved(&tracker, flags: resizeFlags, at: CGPoint(x: 506, y: 500)).command, .grab(.resize))
    }

    func testDeltasWhileAwaitingGrabCarryIntoFirstTarget() {
        var tracker = Tracker()
        _ = moved(&tracker, flags: moveFlags, at: grabPoint)
        _ = moved(&tracker, flags: moveFlags, at: CGPoint(x: 510, y: 500), delta: CGVector(dx: 10, dy: -4))
        tracker.didGrab(window: 1, frame: frame)
        XCTAssertFalse(tracker.isAwaitingGrab)
        let step = moved(&tracker, flags: moveFlags, at: CGPoint(x: 515, y: 503), delta: CGVector(dx: 5, dy: 3))
        // y는 대기 중 커서가 멈춘 축이라 -4 무시, 이후 +3 반영
        XCTAssertEqual(step.command, .apply(window: 1, target: .position(CGPoint(x: 115, y: 203))))
    }

    // 응답 대기가 끝난 뒤 늦게 온 잡기 응답은 무시
    func testLateGrabResultIgnoredWhenNotAwaiting() {
        var tracker = Tracker()
        _ = moved(&tracker, flags: moveFlags, at: grabPoint)
        XCTAssertNil(tracker.handleFlagsChanged(flags: 0, isPaused: false, settings: settings))
        tracker.didGrab(window: 1, frame: frame)
        tracker.grabFailed(.noWindow, location: grabPoint, timestamp: 0)
        XCTAssertFalse(tracker.isActive)
        XCTAssertEqual(moved(&tracker, flags: moveFlags, at: grabPoint).command, .grab(.move))
    }

    // MARK: - flagsChanged

    func testFlagsChangedReleaseEndsImmediately() {
        var tracker = grabbed()
        _ = moved(&tracker, flags: moveFlags, at: CGPoint(x: 510, y: 510), delta: CGVector(dx: 10, dy: 10))
        XCTAssertEqual(tracker.handleFlagsChanged(flags: 0x800000, isPaused: false, settings: settings), w1Move)
        XCTAssertEqual(moved(&tracker, flags: 0x800000, at: CGPoint(x: 520, y: 520), delta: CGVector(dx: 10, dy: 10)).command, .passThrough)
    }

    func testFlagsChangedWhileIdleDoesNothing() {
        var tracker = Tracker()
        XCTAssertNil(tracker.handleFlagsChanged(flags: moveFlags, isPaused: false, settings: settings))
        XCTAssertNil(tracker.handleFlagsChanged(flags: 0, isPaused: false, settings: settings))
        XCTAssertFalse(tracker.isActive)
        XCTAssertEqual(moved(&tracker, flags: moveFlags, at: grabPoint).command, .grab(.move))
    }

    func testFlagsChangedActionSwitchEndsWithoutGrab() {
        var tracker = grabbed()
        XCTAssertEqual(tracker.handleFlagsChanged(flags: resizeFlags, isPaused: false, settings: settings)?.action, .move)
        let step = moved(&tracker, flags: resizeFlags, at: CGPoint(x: 510, y: 500), delta: CGVector(dx: 10, dy: 0))
        XCTAssertEqual(step.command, .grab(.resize))
        XCTAssertNil(step.endedSession)
    }

    func testFlagsChangedExtraModifierOrCapsLockEnds() {
        var tracker = grabbed()
        XCTAssertNotNil(tracker.handleFlagsChanged(flags: moveFlags | 0x20000, isPaused: false, settings: settings))
        var again = grabbed()
        XCTAssertNotNil(again.handleFlagsChanged(flags: moveFlags | 0x10000, isPaused: false, settings: settings))
    }

    func testFlagsChangedIrrelevantBitKeepsSession() {
        var tracker = grabbed()
        XCTAssertNil(tracker.handleFlagsChanged(flags: moveFlags | 0x100, isPaused: false, settings: settings))
        let step = moved(&tracker, flags: moveFlags | 0x100, at: CGPoint(x: 505, y: 500), delta: CGVector(dx: 5, dy: 0))
        XCTAssertEqual(step.command, .apply(window: 1, target: .position(CGPoint(x: 105, y: 200))))
    }

    func testFlagsChangedWhilePausedEnds() {
        var tracker = grabbed()
        XCTAssertEqual(tracker.handleFlagsChanged(flags: moveFlags, isPaused: true, settings: settings), w1Move)
        XCTAssertNil(tracker.endActive())
    }
}
