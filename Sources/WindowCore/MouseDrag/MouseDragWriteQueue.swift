import CoreGraphics
import Foundation

/// 끝난 조작 1건과, 마지막 쓰기 뒤에 다시 읽은 실제 프레임.
public struct MouseDragFinishedOperation<Window> {
    public let session: MouseDragSession<Window>
    public let readResult: Result<CGRect, WindowOpError>
}

/// 마우스 쓰기 실행기의 순서 로직. 실행 타깃은 `MouseDragWriteQueue<AXWindowElement>`로 쓴다.
///
/// - 쓰기는 전용 직렬 큐에서만 하고, 최신 1건 게이트는 그 큐 안에서만 만진다.
/// - 종료 절차는 같은 큐에 "대기 쓰기 실행 → 실제 프레임 읽기"를 넣어 마지막 쓰기 뒤에 읽는다.
/// - 결과는 끝난 순서대로 보관함에 쌓고, 꺼내는 쪽(비동기 알림·동기 마무리) 중 먼저 꺼낸 쪽만 받는다(중복 기록 없음).
/// - 큐 작업 안에서는 메인으로 `deliver`(비동기)만 한다. 메인이 큐를 `sync` 하는 동안 교착하지 않게.
public final class MouseDragWriteQueue<Window: FrameWritable> {
    public typealias Request = (window: Window, target: MouseDragTarget)

    /// 쓰기 중 창이 사라짐(`deliver`로 전달된 블록 안에서 호출).
    public var onWindowGone: ((Window) -> Void)?
    /// 비동기 종료 결과가 보관함에 들어감(`deliver`로 전달된 블록 안에서 호출). 받는 쪽은 `takeFinished()`로 꺼낸다.
    public var onFinished: (() -> Void)?

    private let queue: DispatchQueue
    private let deliver: (@escaping () -> Void) -> Void
    /// 직렬 큐 안에서만 접근
    private var gate = LatestOnlyGate<Request>()
    private let finishedLock = NSLock()
    private var finished: [MouseDragFinishedOperation<Window>] = []

    /// - Parameters:
    ///   - queue: 쓰기 전용 직렬 큐
    ///   - deliver: 블록을 메인 스레드로 비동기 전달한다(앱: `DispatchQueue.main.async`)
    public init(queue: DispatchQueue, deliver: @escaping (@escaping () -> Void) -> Void) {
        self.queue = queue
        self.deliver = deliver
    }

    /// 쓰기 요청. 실행 중에 온 요청은 대기 슬롯을 덮어써 최신 1건만 실행된다.
    public func submit(window: Window, target: MouseDragTarget) {
        queue.async {
            if self.gate.submit((window: window, target: target)) {
                self.queue.async { self.drain() }
            }
        }
    }

    /// 비동기 종료 절차: 대기 쓰기 실행 → 실제 프레임 읽기 → 보관함 → 메인에 알림.
    public func finish(_ session: MouseDragSession<Window>) {
        queue.async {
            self.drain()
            self.store(MouseDragFinishedOperation(session: session, readResult: session.window.readFrame()))
            self.deliver { [weak self] in self?.onFinished?() }
        }
    }

    /// 큐에서 대기 쓰기를 먼저 끝낸 뒤 `work`를 실행하고, 결과를 메인으로 비동기 전달한다.
    /// 잡기 조회(창 찾기·프레임 읽기)를 탭 콜백 밖에서 하되, 앞 조작의 마지막 쓰기·종료 읽기 뒤에 읽게 하기 위함.
    public func perform<T>(_ work: @escaping () -> T, then completion: @escaping (T) -> Void) {
        queue.async {
            self.drain()
            let result = work()
            self.deliver { completion(result) }
        }
    }

    /// 동기 마무리: 큐를 `sync` 해 대기 쓰기를 끝내고, 세션이 있으면 실제 프레임을 읽은 뒤,
    /// 보관함에 쌓인 "끝났지만 아직 꺼내지 않은" 결과까지 끝난 순서대로 모두 꺼내 돌려준다.
    public func finishSync(_ session: MouseDragSession<Window>?) -> [MouseDragFinishedOperation<Window>] {
        queue.sync {
            drain()
            if let session {
                store(MouseDragFinishedOperation(session: session, readResult: session.window.readFrame()))
            }
        }
        return takeFinished()
    }

    /// 보관함을 비우고 끝난 순서대로 돌려준다.
    public func takeFinished() -> [MouseDragFinishedOperation<Window>] {
        finishedLock.lock()
        defer { finishedLock.unlock() }
        let taken = finished
        finished = []
        return taken
    }

    /// 직렬 큐 안에서만 호출한다.
    private func drain() {
        guard let request = gate.takeLatest() else { return }
        let result: Result<Void, WindowOpError>
        switch request.target {
        case .position(let point): result = request.window.setPosition(point)
        case .size(let size): result = request.window.setSize(size)
        }
        if case .failure(.windowGone) = result {
            let window = request.window
            deliver { [weak self] in self?.onWindowGone?(window) }
        }
    }

    private func store(_ operation: MouseDragFinishedOperation<Window>) {
        finishedLock.lock()
        finished.append(operation)
        finishedLock.unlock()
    }
}
