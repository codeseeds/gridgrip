import CoreGraphics
import XCTest
import WindowCore

final class PlacementEngineTests: XCTestCase {
    private let a = PlacementFixtures.a
    private let b = PlacementFixtures.b
    private let start = CGRect(x: 100, y: 100, width: 300, height: 300)
    private let leftThirdOnA = CGRect(x: 0, y: 25, width: 480, height: 875)

    private func makeEngine() -> PlacementEngine<PlacementFakeWindow> {
        PlacementEngine<PlacementFakeWindow>()
    }

    // MARK: - Error Handling (F-3xx)

    func testReadFailure() {
        let window = PlacementFakeWindow(frame: start)
        window.readError = .timedOut
        XCTAssertEqual(makeEngine().perform(.place(.left), on: window, screens: [a]), .failed(.readFailed(.timedOut)))
        XCTAssertEqual(window.calls, [])
    }

    func testNoScreens() {
        let window = PlacementFakeWindow(frame: start)
        XCTAssertEqual(makeEngine().perform(.place(.left), on: window, screens: []), .failed(.noScreen))
        XCTAssertEqual(window.calls, [])
    }

    func testMinimized() {
        let window = PlacementFakeWindow(frame: start)
        window.isMinimized = true
        XCTAssertEqual(makeEngine().perform(.place(.left), on: window, screens: [a]), .failed(.minimized))
        XCTAssertEqual(window.calls, [])
    }

    func testFullScreen() {
        let window = PlacementFakeWindow(frame: start)
        window.isFullScreen = true
        XCTAssertEqual(makeEngine().perform(.place(.left), on: window, screens: [a]), .failed(.fullScreen))
        XCTAssertEqual(window.calls, [])
    }

    func testSizeOnlyFailureCountsAsApplied() {
        let engine = makeEngine()
        let window = PlacementFakeWindow(frame: start)
        window.sizeError = .notSettable
        XCTAssertEqual(engine.perform(.place(.left), on: window, screens: [a]),
                       .applied(before: start, after: CGRect(x: 0, y: 25, width: 300, height: 300)))

        window.clearCalls()
        _ = engine.perform(.place(.left), on: window, screens: [a])
        XCTAssertEqual(window.firstSetSize?.width, 720)
    }

    func testNothingChangedWriteFailure() {
        let engine = makeEngine()
        let window = PlacementFakeWindow(frame: start)
        window.sizeError = .failed(code: -25200)
        window.positionError = .failed(code: -25200)
        guard case .failed(.writeFailed) = engine.perform(.place(.left), on: window, screens: [a]) else {
            return XCTFail("expected .failed(.writeFailed)")
        }

        window.sizeError = nil
        window.positionError = nil
        window.clearCalls()
        _ = engine.perform(.place(.left), on: window, screens: [a])
        XCTAssertEqual(window.firstSetSize?.width, 480)
    }

    func testWindowGoneDuringApply() {
        let window = PlacementFakeWindow(frame: start)
        window.goneAfterSetCalls = 1
        XCTAssertEqual(makeEngine().perform(.place(.left), on: window, screens: [a]), .failed(.windowGone))
    }

    func testWindowGoneOnFirstRead() {
        let window = PlacementFakeWindow(frame: start)
        window.readError = .windowGone
        XCTAssertEqual(makeEngine().perform(.place(.left), on: window, screens: [a]), .failed(.windowGone))
        XCTAssertEqual(window.calls, [])
    }

    // MARK: - Business Logic (F-4xx)

    func testCycleAdvancesDespiteMinimumSize() {
        let engine = makeEngine()
        let window = PlacementFakeWindow(frame: start)
        window.minSize = CGSize(width: 500, height: 0)
        var widths: [CGFloat] = []
        for _ in 0..<3 {
            window.clearCalls()
            _ = engine.perform(.place(.right), on: window, screens: [PlacementFixtures.v])
            widths.append(window.firstSetSize?.width ?? -1)
        }
        XCTAssertEqual(widths, [400, 600, 900])
    }

    func testNormalApplyCallOrder() {
        let window = PlacementFakeWindow(frame: start)
        _ = makeEngine().perform(.place(.left), on: window, screens: [a])
        XCTAssertEqual(window.calls, [
            .setSize(CGSize(width: 480, height: 875)),
            .setPosition(CGPoint(x: 0, y: 25)),
            .setSize(CGSize(width: 480, height: 875)),
        ])
        XCTAssertEqual(window.frame, leftThirdOnA)
    }

    func testBeforeIsFrameReadBeforeAnyWrite() {
        let window = PlacementFakeWindow(frame: start)
        XCTAssertEqual(makeEngine().perform(.place(.left), on: window, screens: [a]),
                       .applied(before: start, after: leftThirdOnA))
    }

    func testNoOpFill() {
        let window = PlacementFakeWindow(frame: a.visibleFrame)
        XCTAssertEqual(makeEngine().perform(.place(.fill), on: window, screens: [a]), .noChange)
        XCTAssertEqual(window.calls, [])
    }

    func testEngineKeepsCycleState() {
        let engine = makeEngine()
        let window = PlacementFakeWindow(frame: start)
        _ = engine.perform(.place(.left), on: window, screens: [a])
        guard case .applied(_, let after) = engine.perform(.place(.left), on: window, screens: [a]) else {
            return XCTFail("expected .applied")
        }
        XCTAssertEqual(after.width, 720)
    }

    func testMinimumSizeCorrection() {
        let window = PlacementFakeWindow(frame: start)
        window.minSize = CGSize(width: 600, height: 0)
        let outcome = makeEngine().perform(.place(.right), on: window, screens: [a])
        XCTAssertEqual(window.calls, [
            .setSize(CGSize(width: 480, height: 875)),
            .setPosition(CGPoint(x: 960, y: 25)),
            .setSize(CGSize(width: 480, height: 875)),
            .setPosition(CGPoint(x: 840, y: 25)),
        ])
        XCTAssertEqual(outcome, .applied(before: start, after: CGRect(x: 840, y: 25, width: 600, height: 875)))
    }

    func testNonResizableWindowOnlyMoves() {
        let window = PlacementFakeWindow(frame: start)
        window.isResizable = false
        let outcome = makeEngine().perform(.place(.bottomRight), on: window, screens: [a])
        XCTAssertEqual(window.calls, [.setPosition(CGPoint(x: 1140, y: 600))])
        XCTAssertEqual(outcome, .applied(before: start, after: CGRect(x: 1140, y: 600, width: 300, height: 300)))
    }

    func testMoveToNextDisplay() {
        let leftHalf = CGRect(x: 0, y: 25, width: 720, height: 875)
        let window = PlacementFakeWindow(frame: leftHalf)
        XCTAssertEqual(makeEngine().perform(.moveToDisplay(.next), on: window, screens: [a, b]),
                       .applied(before: leftHalf, after: CGRect(x: 1440, y: 0, width: 960, height: 1080)))
    }

    func testAlreadyAtThirdAdvancesOnSecondPress() {
        let engine = makeEngine()
        let window = PlacementFakeWindow(frame: leftThirdOnA)
        XCTAssertEqual(engine.perform(.place(.left), on: window, screens: [a]), .noChange)
        XCTAssertEqual(window.calls, [])
        XCTAssertEqual(engine.perform(.place(.left), on: window, screens: [a]),
                       .applied(before: leftThirdOnA, after: CGRect(x: 0, y: 25, width: 720, height: 875)))
    }

    func testDisplayMoveResetsCycle() {
        let engine = makeEngine()
        let window = PlacementFakeWindow(frame: start)
        _ = engine.perform(.place(.left), on: window, screens: [a, b])
        window.clearCalls()
        _ = engine.perform(.place(.left), on: window, screens: [a, b])
        XCTAssertEqual(window.firstSetSize?.width, 720)
        _ = engine.perform(.moveToDisplay(.next), on: window, screens: [a, b])
        window.clearCalls()
        _ = engine.perform(.place(.left), on: window, screens: [a, b])
        XCTAssertEqual(window.firstSetSize?.width, 640)
    }

    // 쓰기 실패가 사이클을 초기화하는지 판별
    func testWriteFailureResetsCycle() {
        let engine = makeEngine()
        let window = PlacementFakeWindow(frame: start)
        XCTAssertEqual(engine.perform(.place(.left), on: window, screens: [a]), .applied(before: start, after: leftThirdOnA))

        window.sizeError = .failed(code: -25200)
        window.positionError = .failed(code: -25200)
        guard case .failed(.writeFailed) = engine.perform(.place(.left), on: window, screens: [a]) else {
            return XCTFail("expected .failed(.writeFailed)")
        }

        // 초기화됐으면 1/3 = 현재 프레임 → 변화 없음. 초기화 안 됐으면 1/2(또는 3/4)로 쓰기 시도.
        window.sizeError = nil
        window.positionError = nil
        window.clearCalls()
        XCTAssertEqual(engine.perform(.place(.left), on: window, screens: [a]), .noChange)
        XCTAssertEqual(window.calls, [])
    }

    // 보정용 setPosition 실패
    func testCorrectionPositionFailureStillApplied() {
        let window = PlacementFakeWindow(frame: start)
        window.minSize = CGSize(width: 600, height: 0)
        window.positionResults = [nil, .timedOut]
        XCTAssertEqual(makeEngine().perform(.place(.right), on: window, screens: [a]),
                       .applied(before: start, after: CGRect(x: 960, y: 25, width: 600, height: 875)))
        XCTAssertEqual(window.calls.count, 4)
    }

    // 최종 다시 읽기에서 창 사라짐
    func testFinalReadWindowGone() {
        let window = PlacementFakeWindow(frame: start)
        window.minSize = CGSize(width: 600, height: 0)
        window.goneAfterSetCalls = 4
        XCTAssertEqual(makeEngine().perform(.place(.right), on: window, screens: [a]), .failed(.windowGone))
        XCTAssertEqual(window.calls.count, 4)
    }

    // 최소 크기 창을 작은 모니터로 보내면 대상 visibleFrame 안으로 밀어 넣는다
    func testDisplayMoveWithMinimumSizeStaysInside() {
        let rightHalfOnB = CGRect(x: 2400, y: 0, width: 960, height: 1080)
        let window = PlacementFakeWindow(frame: rightHalfOnB)
        window.minSize = CGSize(width: 1000, height: 0)
        let outcome = makeEngine().perform(.moveToDisplay(.previous), on: window, screens: [a, b])
        let expected = CGRect(x: 440, y: 25, width: 1000, height: 875)
        XCTAssertEqual(outcome, .applied(before: rightHalfOnB, after: expected))
        XCTAssertTrue(a.visibleFrame.contains(expected))
        XCTAssertEqual(window.calls.last, .setPosition(CGPoint(x: 440, y: 25)))
    }

    // 모니터 이동(변화 없음)·최소화 실패도 사이클을 초기화한다
    func testNoChangeDisplayMoveAndMinimizedResetCycle() {
        let engine = makeEngine()
        let window = PlacementFakeWindow(frame: start)
        XCTAssertEqual(engine.perform(.place(.left), on: window, screens: [a]), .applied(before: start, after: leftThirdOnA))
        XCTAssertEqual(engine.perform(.moveToDisplay(.next), on: window, screens: [a]), .noChange)
        window.clearCalls()
        XCTAssertEqual(engine.perform(.place(.left), on: window, screens: [a]), .noChange)
        XCTAssertEqual(window.calls, [])

        // 위 noChange로 1/3이 기록된 상태 → 최소화 실패 → 다시 1/3부터
        window.isMinimized = true
        XCTAssertEqual(engine.perform(.place(.left), on: window, screens: [a]), .failed(.minimized))
        window.isMinimized = false
        XCTAssertEqual(engine.perform(.place(.left), on: window, screens: [a]), .noChange)
        XCTAssertEqual(window.calls, [])
    }

    // 앱이 오류 없이 크기를 거부해 아무것도 안 바뀌면 "변화 없음"으로 보고 사이클을 기록한다
    func testSilentRejectionRecordsCycle() {
        let engine = makeEngine()
        let nearThird = CGRect(x: 0, y: 25, width: 500, height: 875)
        let window = PlacementFakeWindow(frame: nearThird)
        window.minSize = CGSize(width: 500, height: 0)
        XCTAssertEqual(engine.perform(.place(.left), on: window, screens: [a]), .noChange)

        window.clearCalls()
        XCTAssertEqual(engine.perform(.place(.left), on: window, screens: [a]),
                       .applied(before: nearThird, after: CGRect(x: 0, y: 25, width: 720, height: 875)))
        XCTAssertEqual(window.firstSetSize?.width, 720)
    }
}
