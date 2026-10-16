import CoreGraphics
import Foundation

/// 잡기 실패·조작 중 창 사라짐 사유.
public enum MouseGrabFailure: Equatable {
    case noWindow
    case excluded
    case readFailed
    case timedOut
    case windowGone

    /// true면 실패 지점에서 충분히 멀어지고 시간이 지나면 다시 잡는다. false면 수정자 조합이 바뀔 때까지 다시 잡지 않는다.
    var retriesByDistance: Bool {
        switch self {
        case .noWindow, .excluded, .readFailed: return true
        case .timedOut, .windowGone: return false
        }
    }
}

/// 끝난(또는 진행 중) 조작 정보.
public struct MouseDragSession<Window> {
    public let window: Window
    public let action: MouseAction
    public let initialFrame: CGRect

    public init(window: Window, action: MouseAction, initialFrame: CGRect) {
        self.window = window
        self.action = action
        self.initialFrame = initialFrame
    }
}

extension MouseDragSession: Equatable where Window: Equatable {}

/// 쓰기 목표. 이동은 위치만, 크기조정은 크기만 쓴다(좌상단 고정).
public enum MouseDragTarget: Equatable {
    case position(CGPoint)
    case size(CGSize)
}

/// mouseMoved 처리 결과로 어댑터가 할 일.
public enum MouseDragCommand<Window> {
    /// 이벤트를 그대로 전달
    case passThrough
    /// 커서 아래 창을 잡아 보라(성공하면 이 이벤트는 삼키고 창은 움직이지 않는다)
    case grab(MouseAction)
    /// 이벤트만 삼킨다
    case swallow
    /// 쓰기 요청을 실행기로 보내고 이벤트를 삼킨다
    case apply(window: Window, target: MouseDragTarget)
}

extension MouseDragCommand: Equatable where Window: Equatable {}

public struct MouseDragStep<Window> {
    public let command: MouseDragCommand<Window>
    /// 이 이벤트로 끝난 조작. 어댑터는 종료 절차(마지막 쓰기 뒤 실제 프레임 읽기 → 기록)를 밟는다.
    public let endedSession: MouseDragSession<Window>?

    public init(command: MouseDragCommand<Window>, endedSession: MouseDragSession<Window>? = nil) {
        self.command = command
        self.endedSession = endedSession
    }
}

/// 마우스 이동·크기조정 순수 상태기계. 상태: 대기 / 잡기 응답 대기 / 억제 / 조작 중.
/// 메인 스레드(탭 콜백)에서만 쓴다. 창 타입은 테스트에서 정수, 실행 타깃에서 `AXWindowElement`.
/// 잡기는 비동기다: `.grab`을 낸 뒤 응답(`didGrab`/`grabFailed`)이 올 때까지 같은 조작의 이벤트는 전달하되 델타는 누적해,
/// 잡기 성공 후 첫 목표에 반영한다(탭 콜백이 AX 응답을 기다리며 입력을 막지 않게).
public struct MouseDragTracker<Window: Equatable> {
    /// 거리·시간 재시도 조건(둘 다 충족해야 다시 잡는다).
    public static var retryDistance: CGFloat { 40 }
    public static var retryInterval: TimeInterval { 0.3 }

    private struct Suppression {
        let reason: MouseGrabFailure
        let action: MouseAction
        let location: CGPoint
        let timestamp: TimeInterval
    }

    private struct Active {
        let session: MouseDragSession<Window>
        var accumulated: CGVector
        var lastLocation: CGPoint
    }

    private struct PendingGrab {
        let action: MouseAction
        var accumulated: CGVector
        var lastLocation: CGPoint
    }

    private enum State {
        case idle
        case awaitingGrab(PendingGrab)
        case suppressed(Suppression)
        case active(Active)
    }

    private var state: State = .idle

    public init() {}

    public var isActive: Bool {
        if case .active = state { return true }
        return false
    }

    /// 진행 중인 조작(없으면 nil).
    public var activeSession: MouseDragSession<Window>? {
        if case .active(let active) = state { return active.session }
        return nil
    }

    public mutating func handleMouseMoved(
        flags: UInt64,
        location: CGPoint,
        delta: CGVector,
        timestamp: TimeInterval,
        isPaused: Bool,
        settings: MouseDragSettings
    ) -> MouseDragStep<Window> {
        let action = isPaused ? nil : MouseModifierMatcher.action(for: flags, settings: settings)

        switch state {
        case .active(var active):
            guard action == active.session.action else {
                // 불일치·일시정지·종류 전환: 종료하고, 다른 조작과 일치하면 같은 이벤트에서 다시 잡는다.
                let ended = active.session
                guard let action else {
                    state = .idle
                    return MouseDragStep(command: .passThrough, endedSession: ended)
                }
                state = .awaitingGrab(PendingGrab(action: action, accumulated: .zero, lastLocation: location))
                return MouseDragStep(command: .grab(action), endedSession: ended)
            }
            let moved = Self.effectiveDelta(delta, from: active.lastLocation, to: location)
            active.lastLocation = location
            guard moved.dx != 0 || moved.dy != 0 else {
                state = .active(active)
                return MouseDragStep(command: .swallow)
            }
            active.accumulated.dx += moved.dx
            active.accumulated.dy += moved.dy
            state = .active(active)
            return MouseDragStep(command: .apply(window: active.session.window, target: target(for: active)))

        case .suppressed(let suppression):
            guard let action else {
                state = .idle
                return MouseDragStep(command: .passThrough)
            }
            if action != suppression.action || Self.canRetry(suppression, location: location, timestamp: timestamp) {
                state = .awaitingGrab(PendingGrab(action: action, accumulated: .zero, lastLocation: location))
                return MouseDragStep(command: .grab(action))
            }
            return MouseDragStep(command: .passThrough)

        case .awaitingGrab(var pending) where action == pending.action:
            // 잡기 응답 전: 다시 요청하지 않고 전달하되, 잡기 성공 후 창이 커서를 따라잡도록 델타를 누적한다.
            let moved = Self.effectiveDelta(delta, from: pending.lastLocation, to: location)
            pending.lastLocation = location
            pending.accumulated.dx += moved.dx
            pending.accumulated.dy += moved.dy
            state = .awaitingGrab(pending)
            return MouseDragStep(command: .passThrough)

        case .idle, .awaitingGrab:
            guard let action else {
                state = .idle
                return MouseDragStep(command: .passThrough)
            }
            state = .awaitingGrab(PendingGrab(action: action, accumulated: .zero, lastLocation: location))
            return MouseDragStep(command: .grab(action))
        }
    }

    /// flagsChanged 판정. 명령을 돌려주지 않으므로 어댑터는 구조적으로 이 이벤트를 삼킬 수 없다.
    /// 반환값은 이 변경으로 끝난 조작뿐이다. 대기 중에는 아무것도 하지 않는다(잡기는 다음 mouseMoved에서).
    public mutating func handleFlagsChanged(flags: UInt64, isPaused: Bool, settings: MouseDragSettings) -> MouseDragSession<Window>? {
        let action = isPaused ? nil : MouseModifierMatcher.action(for: flags, settings: settings)

        switch state {
        case .active(let active):
            guard action != active.session.action else { return nil }
            state = .idle
            return active.session
        case .suppressed(let suppression):
            if action != suppression.action { state = .idle }
            return nil
        case .awaitingGrab:
            state = .idle
            return nil
        case .idle:
            return nil
        }
    }

    /// 잡기 응답을 기다리는 중인지. 늦게 온 응답을 버릴 때 어댑터가 확인한다.
    public var isAwaitingGrab: Bool {
        if case .awaitingGrab = state { return true }
        return false
    }

    /// 잡기 성공. 잡기 응답 대기 중일 때만 반영한다. 대기 중 누적된 델타는 첫 목표에 반영된다.
    public mutating func didGrab(window: Window, frame: CGRect) {
        guard case .awaitingGrab(let pending) = state else { return }
        let session = MouseDragSession(window: window, action: pending.action, initialFrame: frame)
        state = .active(Active(session: session, accumulated: pending.accumulated, lastLocation: pending.lastLocation))
    }

    /// 잡기 실패 → 억제. 잡기 응답 대기 중일 때만 반영한다. location·timestamp는 잡기를 요청한 지점·시각이다.
    public mutating func grabFailed(_ reason: MouseGrabFailure, location: CGPoint, timestamp: TimeInterval) {
        guard case .awaitingGrab(let pending) = state else { return }
        state = .suppressed(Suppression(reason: reason, action: pending.action, location: location, timestamp: timestamp))
    }

    /// 조작 중 창이 사라짐. 같은 창으로 조작 중일 때만 세션 없이(기록 없이) 끝내고 수정자 변경까지 억제한다.
    public mutating func windowDisappeared(_ window: Window) {
        guard case .active(let active) = state, active.session.window == window else { return }
        state = .suppressed(Suppression(reason: .windowGone, action: active.session.action, location: active.lastLocation, timestamp: 0))
    }

    /// 강제 종료(정지·동기 마무리용). 조작 중일 때만 세션을 돌려주고 대기로 간다.
    public mutating func endActive() -> MouseDragSession<Window>? {
        guard case .active(let active) = state else { return nil }
        state = .idle
        return active.session
    }

    private func target(for active: Active) -> MouseDragTarget {
        let frame = active.session.initialFrame
        switch active.session.action {
        case .move:
            return .position(CGPoint(x: frame.origin.x + active.accumulated.dx, y: frame.origin.y + active.accumulated.dy))
        case .resize:
            let size = CGSize(width: frame.size.width + active.accumulated.dx, height: frame.size.height + active.accumulated.dy)
            return .size(MouseDragGeometry.clampedSize(size))
        }
    }

    /// 커서가 멈춘 축은 델타를 무시한다(화면 끝에서 창이 흘러가지 않게).
    private static func effectiveDelta(_ delta: CGVector, from last: CGPoint, to location: CGPoint) -> CGVector {
        CGVector(dx: location.x == last.x ? 0 : delta.dx, dy: location.y == last.y ? 0 : delta.dy)
    }

    private static func canRetry(_ suppression: Suppression, location: CGPoint, timestamp: TimeInterval) -> Bool {
        guard suppression.reason.retriesByDistance else { return false }
        let distance = hypot(location.x - suppression.location.x, location.y - suppression.location.y)
        return distance >= retryDistance && timestamp - suppression.timestamp >= retryInterval
    }
}
