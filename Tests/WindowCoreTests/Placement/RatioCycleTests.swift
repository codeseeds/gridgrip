import CoreGraphics
import XCTest
import WindowCore

final class RatioCycleTests: XCTestCase {
    private let third: CGFloat = 1.0 / 3
    private let half: CGFloat = 1.0 / 2
    private let threeQuarters: CGFloat = 3.0 / 4
    private let frame1 = CGRect(x: 0, y: 30, width: 400, height: 900)
    private let frame2 = CGRect(x: 0, y: 30, width: 600, height: 900)

    func testSameKeySameWindowCycles() {
        var cycle = RatioCycle<PlacementFakeWindow>()
        let w1 = PlacementFakeWindow(frame: .zero)
        var current = CGRect(x: 100, y: 100, width: 300, height: 300)
        var ratios: [CGFloat] = []
        for _ in 0..<4 {
            let ratio = cycle.nextRatio(for: .left, window: w1, currentFrame: current)
            ratios.append(ratio)
            current = CGRect(x: 0, y: 30, width: 1200 * ratio, height: 900)
            cycle.record(placement: .left, window: w1, frame: current)
        }
        XCTAssertEqual(ratios, [third, half, threeQuarters, third])
    }

    func testDifferentPlacementResets() {
        var cycle = RatioCycle<PlacementFakeWindow>()
        let w1 = PlacementFakeWindow(frame: .zero)
        XCTAssertEqual(cycle.nextRatio(for: .left, window: w1, currentFrame: .zero), third)
        cycle.record(placement: .left, window: w1, frame: frame1)
        XCTAssertEqual(cycle.nextRatio(for: .left, window: w1, currentFrame: frame1), half)
        cycle.record(placement: .left, window: w1, frame: frame2)
        XCTAssertEqual(cycle.nextRatio(for: .right, window: w1, currentFrame: frame2), third)
    }

    func testDifferentWindowResets() {
        var cycle = RatioCycle<PlacementFakeWindow>()
        let w1 = PlacementFakeWindow(frame: .zero)
        let w2 = PlacementFakeWindow(frame: .zero)
        XCTAssertEqual(cycle.nextRatio(for: .left, window: w1, currentFrame: .zero), third)
        cycle.record(placement: .left, window: w1, frame: frame1)
        XCTAssertEqual(cycle.nextRatio(for: .left, window: w1, currentFrame: frame1), half)
        cycle.record(placement: .left, window: w1, frame: frame2)
        XCTAssertEqual(cycle.nextRatio(for: .left, window: w2, currentFrame: frame2), third)
    }

    func testExternalMoveBeyondToleranceResets() {
        let w1 = PlacementFakeWindow(frame: .zero)

        var moved = RatioCycle<PlacementFakeWindow>()
        _ = moved.nextRatio(for: .left, window: w1, currentFrame: .zero)
        moved.record(placement: .left, window: w1, frame: frame1)
        XCTAssertEqual(moved.nextRatio(for: .left, window: w1, currentFrame: frame1.offsetBy(dx: 10, dy: 0)), third)

        var nudged = RatioCycle<PlacementFakeWindow>()
        _ = nudged.nextRatio(for: .left, window: w1, currentFrame: .zero)
        nudged.record(placement: .left, window: w1, frame: frame1)
        XCTAssertEqual(nudged.nextRatio(for: .left, window: w1, currentFrame: frame1.offsetBy(dx: 1.5, dy: 0)), half)
    }

    func testResetStartsOver() {
        var cycle = RatioCycle<PlacementFakeWindow>()
        let w1 = PlacementFakeWindow(frame: .zero)
        XCTAssertEqual(cycle.nextRatio(for: .left, window: w1, currentFrame: .zero), third)
        cycle.record(placement: .left, window: w1, frame: frame1)
        XCTAssertEqual(cycle.nextRatio(for: .left, window: w1, currentFrame: frame1), half)
        cycle.record(placement: .left, window: w1, frame: frame2)
        cycle.reset()
        XCTAssertEqual(cycle.nextRatio(for: .left, window: w1, currentFrame: frame2), third)
    }

    // nextRatio 뒤 record 없이 다시 nextRatio를 불러도 직전 기록 기준으로 판정한다
    func testNextRatioWithoutRecordDoesNotAdvance() {
        var cycle = RatioCycle<PlacementFakeWindow>()
        let w1 = PlacementFakeWindow(frame: .zero)
        _ = cycle.nextRatio(for: .left, window: w1, currentFrame: .zero)
        cycle.record(placement: .left, window: w1, frame: frame1)
        XCTAssertEqual(cycle.nextRatio(for: .left, window: w1, currentFrame: frame1), half)
        XCTAssertEqual(cycle.nextRatio(for: .left, window: w1, currentFrame: frame1), half)
    }
}
