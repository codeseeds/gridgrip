import AppKit
import os
import WindowCore

/// 커서 아래 창 잡기 조회 결과(실행기 큐에서 만든다).
private enum MouseDragGrabLookup {
    case found(window: AXWindowElement, frame: CGRect, bundleIdentifier: String?)
    case failed(MouseGrabFailure)
}

/// 탭 콜백 ↔ 판정기 ↔ 추적기 ↔ AX(잡기) ↔ 실행기 ↔ 창 변경 허브 연결.
/// 메인 스레드 전용. 탭 콜백 안에서는 AX 응답을 기다리지 않는다: 쓰기와 잡기 조회(창 찾기·프레임 읽기)를
/// 모두 실행기 직렬 큐로 넘긴다. 같은 큐라서 잡기 조회는 앞 조작의 마지막 쓰기·종료 읽기 뒤에 실행된다.
@MainActor
final class MouseDragController {
    private let activation: ActivationPolicy
    private let windowChanges: WindowChangeHub
    private let settingsStore: MouseDragSettingsStore
    private let logger = Logger(subsystem: AppIdentity.bundleIdentifier, category: "mouse")
    private let tap = MouseEventTap()
    private let executor = MouseDragExecutor.makeForApp()

    private var tracker = MouseDragTracker<AXWindowElement>()
    private var settings: MouseDragSettings
    private var settingsObserver: NSObjectProtocol?
    /// 잡기 요청마다 1씩 늘린다. 응답의 번호가 최신이 아니면(그 사이 수정자를 뗐다 다시 누름 등) 버린다.
    private var grabRequestID = 0

    init(activation: ActivationPolicy, windowChanges: WindowChangeHub, settingsStore: MouseDragSettingsStore) {
        self.activation = activation
        self.windowChanges = windowChanges
        self.settingsStore = settingsStore
        self.settings = settingsStore.load()

        executor.onFinished = { [weak self] in
            MainActor.assumeIsolated { self?.recordFinishedOperations() }
        }
        executor.onWindowGone = { [weak self] window in
            MainActor.assumeIsolated { self?.windowDidDisappear(window) }
        }
        tap.handler = { [weak self] type, event in
            MainActor.assumeIsolated { self?.handle(type, event) ?? false }
        }
    }

    /// 탭 생성 → (성공 후에만) 설정 변경 구독. 이미 실행 중이면 아무것도 하지 않는다.
    func start() throws {
        guard !tap.isRunning else { return }
        reloadSettings()
        do {
            try tap.start()
        } catch {
            logger.error("이벤트 탭 생성 실패")
            throw error
        }
        settingsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reloadSettings() }
        }
        logger.info("이벤트 탭 시작")
    }

    /// 진행 중 조작 동기 마무리(기록 포함) → 탭 끄기 → 구독 해제 → 추적기 초기화.
    func stop() {
        guard tap.isRunning else { return }
        finishActiveOperationSynchronously()
        tap.stop()
        if let settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
        }
        settingsObserver = nil
        tracker = MouseDragTracker()
        logger.info("이벤트 탭 정지")
    }

    func reloadSettings() {
        settings = settingsStore.load()
    }

    /// `WindowChangeHub.finishPendingOperations()`에 등록되는 마무리 함수.
    /// 큐를 sync로 비우고 진행 중 조작의 실제 프레임까지 읽은 뒤, 끝난 순서대로 기록하고 돌아온다.
    func finishActiveOperationSynchronously() {
        let session = tracker.endActive()
        record(executor.finishSync(session))
    }

    // MARK: - 이벤트

    /// true = 이벤트를 삼킨다. flagsChanged는 탭이 반환값과 무관하게 항상 전달한다.
    private func handle(_ type: CGEventType, _ event: CGEvent) -> Bool {
        let flags = event.flags.rawValue
        let isPaused = activation.isPaused

        if type == .flagsChanged {
            if let ended = tracker.handleFlagsChanged(flags: flags, isPaused: isPaused, settings: settings) {
                end(ended)
            }
            if !tracker.isActive {
                // 다른 프로세스(`defaults write`)의 변경은 didChangeNotification이 오지 않으므로
                // 대기 중 수정자 키를 누를 때마다 다시 읽는다.
                reloadSettings()
            }
            return false
        }

        guard type == .mouseMoved else { return false }
        let location = event.location
        let delta = CGVector(
            dx: CGFloat(event.getIntegerValueField(.mouseEventDeltaX)),
            dy: CGFloat(event.getIntegerValueField(.mouseEventDeltaY))
        )
        let timestamp = ProcessInfo.processInfo.systemUptime
        let step = tracker.handleMouseMoved(
            flags: flags, location: location, delta: delta, timestamp: timestamp, isPaused: isPaused, settings: settings
        )
        if let ended = step.endedSession {
            end(ended)
        }

        switch step.command {
        case .passThrough:
            return false
        case .swallow:
            return true
        case .apply(let window, let target):
            executor.submit(window: window, target: target)
            return true
        case .grab:
            requestGrab(at: location, timestamp: timestamp)
            return false
        }
    }

    /// 잡기 요청: 실행기 큐에서 커서 아래 창 찾기 → 프레임 읽기 → 번들 ID를 구해 메인으로 돌려받는다.
    /// 응답 전 이벤트는 전달하고(추적기가 델타만 누적), 응답이 오면 제외 앱 확인 → 잡기 → (옵션) 앱 앞으로.
    /// 잡기 요청 이벤트 자체도 전달한다(아직 창을 잡지 않았으므로 삼키지 않는다).
    private func requestGrab(at location: CGPoint, timestamp: TimeInterval) {
        grabRequestID += 1
        let requestID = grabRequestID
        executor.perform({ Self.lookUpWindow(at: location) }, then: { [weak self] lookup in
            MainActor.assumeIsolated {
                self?.completeGrab(lookup, requestID: requestID, location: location, timestamp: timestamp)
            }
        })
    }

    private func completeGrab(_ lookup: MouseDragGrabLookup, requestID: Int, location: CGPoint, timestamp: TimeInterval) {
        guard tap.isRunning, requestID == grabRequestID, tracker.isAwaitingGrab else { return }
        switch lookup {
        case .failed(let reason):
            grabFailed(reason, at: location, timestamp: timestamp)
        case .found(let window, let frame, let bundleIdentifier):
            // 제외 앱의 창은 읽기만 했고 아무것도 바꾸지 않았다. 앞으로 가져오기·쓰기는 이 확인 뒤에만 한다.
            if activation.isExcluded(bundleIdentifier: bundleIdentifier) {
                grabFailed(.excluded, at: location, timestamp: timestamp)
                return
            }
            tracker.didGrab(window: window, frame: frame)
            if settings.bringWindowToFront {
                executor.perform({ window.bringAppToFront() }, then: { _ in })
            }
        }
    }

    /// 실행기 큐에서만 호출한다. 응답 없는 앱은 `.timedOut`(수정자를 바꿀 때까지 재시도 안 함)으로 구분한다.
    nonisolated private static func lookUpWindow(at location: CGPoint) -> MouseDragGrabLookup {
        let window: AXWindowElement
        switch AXWindowElement.lookup(at: location) {
        case .found(let found): window = found
        case .noWindow: return .failed(.noWindow)
        case .failed(.timedOut): return .failed(.timedOut)
        case .failed: return .failed(.readFailed)
        }
        switch window.readFrame() {
        case .success(let frame):
            return .found(window: window, frame: frame, bundleIdentifier: window.bundleIdentifier)
        case .failure(.timedOut):
            return .failed(.timedOut)
        case .failure(.windowGone):
            return .failed(.windowGone)
        case .failure:
            return .failed(.readFailed)
        }
    }

    /// 억제 상태 진입(그 동안 이벤트는 전달). 로그는 진입 때 1회만 남는다.
    private func grabFailed(_ reason: MouseGrabFailure, at location: CGPoint, timestamp: TimeInterval) {
        tracker.grabFailed(reason, location: location, timestamp: timestamp)
        logger.debug("잡기 실패 \(String(describing: reason), privacy: .public)")
    }

    // MARK: - 종료·기록

    /// 종료 절차: 추적기는 이미 대기 → 실행기 큐에 "마지막 쓰기 → 실제 프레임 읽기" → 결과는 메인에서 기록.
    private func end(_ session: MouseDragSession<AXWindowElement>) {
        executor.finish(session)
    }

    private func recordFinishedOperations() {
        record(executor.takeFinished())
    }

    private func record(_ operations: [MouseDragFinishedOperation<AXWindowElement>]) {
        for operation in operations {
            guard let change = MouseDragRecordDecision.make(session: operation.session, readResult: operation.readResult) else {
                continue
            }
            windowChanges.record(operation.session.window, before: change.before, after: change.after, source: change.source)
            logger.debug(
                "record \(String(describing: change.source), privacy: .public) before=\(Self.describe(change.before), privacy: .public) after=\(Self.describe(change.after), privacy: .public)"
            )
        }
    }

    /// 쓰기 중 창이 사라짐 → 그 창으로 조작 중이면 기록 없이 끝내고 수정자 변경까지 억제한다.
    private func windowDidDisappear(_ window: AXWindowElement) {
        guard tracker.activeSession?.window == window else { return }
        tracker.windowDisappeared(window)
        logger.debug("조작 중 창 사라짐")
    }

    private static func describe(_ rect: CGRect) -> String {
        "(\(Int(rect.origin.x)),\(Int(rect.origin.y)),\(Int(rect.size.width)),\(Int(rect.size.height)))"
    }
}
