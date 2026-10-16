import CoreGraphics
import Foundation
import XCTest
import WindowCore

/// 쓰기 결과를 지정할 수 있고, 위치·크기 쓰기를 실제 프레임에 반영하는 가짜 창.
/// 직렬 큐 안에서만 만지고, 테스트는 `finishSync`(큐 sync) 뒤에 읽는다.
fileprivate final class MouseDragWriteQueueFakeWindow: FrameWritable, Equatable {
    enum Call: Equatable {
        case read
        case setPosition(CGPoint)
        case setSize(CGSize)
    }

    let id: Int
    var frame = CGRect(x: 100, y: 200, width: 800, height: 600)
    var writeResult: Result<Void, WindowOpError> = .success(())
    private(set) var calls: [Call] = []

    init(id: Int) {
        self.id = id
    }

    static func == (lhs: MouseDragWriteQueueFakeWindow, rhs: MouseDragWriteQueueFakeWindow) -> Bool {
        lhs.id == rhs.id
    }

    func readFrame() -> Result<CGRect, WindowOpError> {
        calls.append(.read)
        return .success(frame)
    }

    func setPosition(_ p: CGPoint) -> Result<Void, WindowOpError> {
        calls.append(.setPosition(p))
        if case .success = writeResult { frame.origin = p }
        return writeResult
    }

    func setSize(_ s: CGSize) -> Result<Void, WindowOpError> {
        calls.append(.setSize(s))
        if case .success = writeResult { frame.size = s }
        return writeResult
    }
}

final class MouseDragWriteQueueTests: XCTestCase {
    private typealias Window = MouseDragWriteQueueFakeWindow
    private typealias WriteQueue = MouseDragWriteQueue<Window>

    private var delivered: [() -> Void] = []
    private var queue: DispatchQueue!
    private var writeQueue: WriteQueue!

    override func setUp() {
        super.setUp()
        delivered = []
        queue = DispatchQueue(label: "MouseDragWriteQueueTests-\(UUID().uuidString)")
        let lock = NSLock()
        writeQueue = WriteQueue(queue: queue) { [weak self] block in
            lock.lock()
            self?.delivered.append(block)
            lock.unlock()
        }
    }

    override func tearDown() {
        writeQueue = nil
        queue = nil
        delivered = []
        super.tearDown()
    }

    private func runDelivered() {
        queue.sync {}
        let blocks = delivered
        delivered = []
        blocks.forEach { $0() }
    }

    private func session(_ window: Window, _ action: MouseAction = .move) -> MouseDragSession<Window> {
        MouseDragSession(window: window, action: action, initialFrame: CGRect(x: 100, y: 200, width: 800, height: 600))
    }

    func testFinishSyncRunsLatestWriteThenReadsActualFrame() {
        let window = Window(id: 1)
        let gate = DispatchSemaphore(value: 0)
        queue.async { gate.wait() }
        for value in [1, 2, 3] {
            writeQueue.submit(window: window, target: .position(CGPoint(x: value, y: value)))
        }
        gate.signal()

        let finished = writeQueue.finishSync(session(window))
        XCTAssertEqual(window.calls, [.setPosition(CGPoint(x: 3, y: 3)), .read])
        XCTAssertEqual(finished.count, 1)
        XCTAssertEqual(finished.first?.session, session(window))
        XCTAssertEqual(finished.first?.readResult, .success(CGRect(x: 3, y: 3, width: 800, height: 600)))
    }

    func testAsyncFinishedOperationIsTakenOnlyOnce() {
        let window = Window(id: 1)
        var notified = 0
        var takenLater: [MouseDragFinishedOperation<Window>] = []
        writeQueue.onFinished = { [unowned self] in
            notified += 1
            takenLater += self.writeQueue.takeFinished()
        }

        writeQueue.finish(session(window))
        let finished = writeQueue.finishSync(nil)
        XCTAssertEqual(finished.map(\.session), [session(window)])

        runDelivered()
        XCTAssertEqual(notified, 1)
        XCTAssertTrue(takenLater.isEmpty)
        XCTAssertTrue(writeQueue.takeFinished().isEmpty)
    }

    func testFinishedOperationsKeepEndOrder() {
        let a = Window(id: 1)
        let b = Window(id: 2)
        writeQueue.finish(session(a, .move))
        writeQueue.finish(session(b, .resize))
        XCTAssertEqual(writeQueue.finishSync(nil).map(\.session), [session(a, .move), session(b, .resize)])
    }

    func testWindowGoneOnWriteIsDelivered() {
        let window = Window(id: 7)
        window.writeResult = .failure(.windowGone)
        var gone: [Window] = []
        writeQueue.onWindowGone = { gone.append($0) }

        writeQueue.submit(window: window, target: .position(CGPoint(x: 10, y: 10)))
        _ = writeQueue.finishSync(nil)
        runDelivered()
        XCTAssertEqual(gone, [window])
    }

    func testFinishSyncWithoutPendingWriteOnlyReads() {
        let window = Window(id: 1)
        let finished = writeQueue.finishSync(session(window))
        XCTAssertEqual(window.calls, [.read])
        XCTAssertEqual(finished.count, 1)
    }

    func testPerformRunsAfterPendingWriteAndDeliversResult() {
        let window = Window(id: 1)
        let gate = DispatchSemaphore(value: 0)
        queue.async { gate.wait() }
        writeQueue.submit(window: window, target: .position(CGPoint(x: 9, y: 9)))
        var results: [CGRect] = []
        writeQueue.perform({ () -> CGRect in
            // 대기 쓰기가 먼저 실행됐어야 한다
            if case .success(let frame) = window.readFrame() { return frame }
            return .null
        }, then: { results.append($0) })
        gate.signal()

        runDelivered()
        XCTAssertEqual(window.calls, [.setPosition(CGPoint(x: 9, y: 9)), .read])
        XCTAssertEqual(results, [CGRect(x: 9, y: 9, width: 800, height: 600)])
    }

    /// 크기 목표는 setSize로만 쓴다(위치는 건드리지 않음 — 좌상단 고정).
    func testSizeTargetWritesOnlySize() {
        let window = Window(id: 1)
        writeQueue.submit(window: window, target: .size(CGSize(width: 300, height: 200)))
        _ = writeQueue.finishSync(nil)
        XCTAssertEqual(window.calls, [.setSize(CGSize(width: 300, height: 200))])
    }
}
