import CoreGraphics
import XCTest
import WindowCore

/// 읽기 결과 큐·쓰기 결과·호출 기록을 가진 가짜 창.
fileprivate final class FrameWriterFakeWindow: FrameWritable {
    enum Call: Equatable {
        case read
        case setPosition(CGPoint)
        case setSize(CGSize)
    }

    var reads: [Result<CGRect, WindowOpError>]
    var positionResult: Result<Void, WindowOpError> = .success(())
    var sizeResults: [Result<Void, WindowOpError>] = []
    private(set) var calls: [Call] = []

    init(reads: [Result<CGRect, WindowOpError>]) {
        self.reads = reads
    }

    func readFrame() -> Result<CGRect, WindowOpError> {
        calls.append(.read)
        return reads.isEmpty ? .failure(.windowGone) : reads.removeFirst()
    }

    func setPosition(_ p: CGPoint) -> Result<Void, WindowOpError> {
        calls.append(.setPosition(p))
        return positionResult
    }

    func setSize(_ s: CGSize) -> Result<Void, WindowOpError> {
        calls.append(.setSize(s))
        return sizeResults.isEmpty ? .success(()) : sizeResults.removeFirst()
    }
}

final class FrameWriterTests: XCTestCase {
    private let start = CGRect(x: 0, y: 0, width: 500, height: 400)
    private let target = CGRect(x: 100, y: 50, width: 800, height: 600)

    func testReachedAndCallOrder() {
        let window = FrameWriterFakeWindow(reads: [.success(start), .success(target)])
        XCTAssertEqual(FrameWriter.apply(target, to: window), .reached(actual: target))
        XCTAssertEqual(window.calls, [
            .read,
            .setSize(CGSize(width: 800, height: 600)),
            .setPosition(CGPoint(x: 100, y: 50)),
            .setSize(CGSize(width: 800, height: 600)),
            .read,
        ])
    }

    func testPartialWhenMovedButNotReached() {
        let moved = CGRect(x: 100, y: 50, width: 500, height: 400)
        let window = FrameWriterFakeWindow(reads: [.success(start), .success(moved)])
        window.sizeResults = [.failure(.notSettable), .failure(.notSettable)]
        XCTAssertEqual(FrameWriter.apply(target, to: window), .partial(actual: moved))
    }

    func testFailedWhenNothingChanged() {
        let failing = FrameWriterFakeWindow(reads: [.success(start), .success(CGRect(x: 1, y: 1, width: 500, height: 400))])
        failing.positionResult = .failure(.failed(code: -25200))
        failing.sizeResults = [.failure(.failed(code: -25200)), .failure(.failed(code: -25200))]
        XCTAssertEqual(FrameWriter.apply(target, to: failing), .failed(.failed(code: -25200)))

        let ignored = FrameWriterFakeWindow(reads: [.success(start), .success(start)])
        XCTAssertEqual(FrameWriter.apply(target, to: ignored), .failed(nil))
    }

    func testWindowGoneAndReadFailures() {
        let goneBefore = FrameWriterFakeWindow(reads: [.failure(.windowGone)])
        XCTAssertEqual(FrameWriter.apply(target, to: goneBefore), .windowGone)
        XCTAssertEqual(goneBefore.calls, [.read])

        let timedOutBefore = FrameWriterFakeWindow(reads: [.failure(.timedOut)])
        XCTAssertEqual(FrameWriter.apply(target, to: timedOutBefore), .failed(.timedOut))
        XCTAssertEqual(timedOutBefore.calls, [.read])

        let goneAfter = FrameWriterFakeWindow(reads: [.success(start), .failure(.windowGone)])
        XCTAssertEqual(FrameWriter.apply(target, to: goneAfter), .windowGone)

        let failedAfter = FrameWriterFakeWindow(reads: [.success(start), .failure(.failed(code: -25212))])
        XCTAssertEqual(FrameWriter.apply(target, to: failedAfter), .failed(.failed(code: -25212)))
    }

    func testCanResizeFalseSkipsSize() {
        let window = FrameWriterFakeWindow(reads: [.success(start), .success(target)])
        _ = FrameWriter.apply(target, to: window, canResize: false)
        XCTAssertEqual(window.calls, [.read, .setPosition(CGPoint(x: 100, y: 50)), .read])
    }

    func testTimedOutWriteSkipsRemainingWrites() {
        let slow = FrameWriterFakeWindow(reads: [.success(start), .success(start)])
        slow.sizeResults = [.failure(.timedOut)]
        XCTAssertEqual(FrameWriter.apply(target, to: slow), .failed(.timedOut))
        XCTAssertEqual(slow.calls, [.read, .setSize(CGSize(width: 800, height: 600)), .read])

        let gone = FrameWriterFakeWindow(reads: [.success(start), .failure(.windowGone)])
        gone.sizeResults = [.failure(.windowGone)]
        XCTAssertEqual(FrameWriter.apply(target, to: gone), .windowGone)
        XCTAssertEqual(gone.calls, [.read, .setSize(CGSize(width: 800, height: 600)), .read])
    }
}
