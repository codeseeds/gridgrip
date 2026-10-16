import CoreGraphics
import XCTest
import WindowCore

final class PlacementCalculatorTests: XCTestCase {
    private let vf = PlacementFixtures.vf
    private let size = CGSize(width: 500, height: 400)
    private let third: CGFloat = 1.0 / 3
    private let half: CGFloat = 1.0 / 2
    private let threeQuarters: CGFloat = 3.0 / 4

    private func frame(_ placement: Placement, _ ratio: CGFloat, in visible: CGRect? = nil, size: CGSize? = nil) -> CGRect {
        PlacementCalculator.frame(for: placement, ratio: ratio, in: visible ?? vf, currentSize: size ?? self.size)
    }

    func testTopLeftThreeRatios() {
        XCTAssertEqual(frame(.topLeft, third), CGRect(x: 0, y: 30, width: 400, height: 300))
        XCTAssertEqual(frame(.topLeft, half), CGRect(x: 0, y: 30, width: 600, height: 450))
        XCTAssertEqual(frame(.topLeft, threeQuarters), CGRect(x: 0, y: 30, width: 900, height: 675))
    }

    func testTopRight() {
        XCTAssertEqual(frame(.topRight, third), CGRect(x: 800, y: 30, width: 400, height: 300))
        XCTAssertEqual(frame(.topRight, threeQuarters), CGRect(x: 300, y: 30, width: 900, height: 675))
    }

    func testBottomLeft() {
        XCTAssertEqual(frame(.bottomLeft, third), CGRect(x: 0, y: 630, width: 400, height: 300))
        XCTAssertEqual(frame(.bottomLeft, half), CGRect(x: 0, y: 480, width: 600, height: 450))
    }

    func testBottomRight() {
        XCTAssertEqual(frame(.bottomRight, third), CGRect(x: 800, y: 630, width: 400, height: 300))
        XCTAssertEqual(frame(.bottomRight, threeQuarters), CGRect(x: 300, y: 255, width: 900, height: 675))
    }

    func testLeftKeepsFullHeight() {
        XCTAssertEqual(frame(.left, third), CGRect(x: 0, y: 30, width: 400, height: 900))
        XCTAssertEqual(frame(.left, half), CGRect(x: 0, y: 30, width: 600, height: 900))
        XCTAssertEqual(frame(.left, threeQuarters), CGRect(x: 0, y: 30, width: 900, height: 900))
    }

    func testRight() {
        XCTAssertEqual(frame(.right, third), CGRect(x: 800, y: 30, width: 400, height: 900))
        XCTAssertEqual(frame(.right, half), CGRect(x: 600, y: 30, width: 600, height: 900))
    }

    func testTopKeepsFullWidth() {
        XCTAssertEqual(frame(.top, third), CGRect(x: 0, y: 30, width: 1200, height: 300))
        XCTAssertEqual(frame(.top, half), CGRect(x: 0, y: 30, width: 1200, height: 450))
    }

    func testBottom() {
        XCTAssertEqual(frame(.bottom, third), CGRect(x: 0, y: 630, width: 1200, height: 300))
        XCTAssertEqual(frame(.bottom, threeQuarters), CGRect(x: 0, y: 255, width: 1200, height: 675))
    }

    func testCenterKeepsSize() {
        let expected = CGRect(x: 350, y: 280, width: 500, height: 400)
        for ratio in PlacementRatio.cycle {
            XCTAssertEqual(frame(.center, ratio), expected)
        }
    }

    func testFillIsVisibleFrame() {
        for ratio in PlacementRatio.cycle {
            XCTAssertEqual(frame(.fill, ratio), vf)
            XCTAssertEqual(frame(.fill, ratio, size: CGSize(width: 2000, height: 50)), vf)
        }
    }

    func testAllGridResultsInsideVisibleFrame() {
        let grid: [Placement] = [.topLeft, .top, .topRight, .left, .center, .right, .bottomLeft, .bottom, .bottomRight]
        var count = 0
        for placement in grid {
            for ratio in PlacementRatio.cycle {
                let result = frame(placement, ratio)
                XCTAssertTrue(vf.contains(result), "\(placement) \(ratio) → \(result)")
                count += 1
            }
        }
        XCTAssertEqual(count, 27)
    }

    func testOddWidthSeamHasNoGapOrOverlap() {
        let vf2 = CGRect(x: 0, y: 25, width: 1439, height: 875)
        let left = frame(.left, half, in: vf2)
        let right = frame(.right, half, in: vf2)
        XCTAssertEqual(left.maxX, 720)
        XCTAssertEqual(right.minX, 720)
        XCTAssertEqual(left.width, 720)
        XCTAssertEqual(right.width, 719)
        XCTAssertEqual(left.width + right.width, 1439)
    }

    func testAllResultsAreIntegral() {
        let vf2 = CGRect(x: 0, y: 25, width: 1439, height: 875)
        let grid: [Placement] = [.topLeft, .top, .topRight, .left, .center, .right, .bottomLeft, .bottom, .bottomRight]
        for placement in grid {
            for ratio in PlacementRatio.cycle {
                let r = frame(placement, ratio, in: vf2, size: CGSize(width: 500.5, height: 399.3))
                for value in [r.origin.x, r.origin.y, r.width, r.height] {
                    XCTAssertEqual(value.rounded(), value, "\(placement) \(ratio) → \(r)")
                }
            }
        }
    }

    func testCenterShrinksOversizedWindow() {
        XCTAssertEqual(frame(.center, third, size: CGSize(width: 1300, height: 1000)),
                       CGRect(x: 0, y: 30, width: 1200, height: 900))
    }

    func testZeroVisibleFrameDoesNotCrash() {
        let zero = CGRect.zero
        for placement in [Placement.topLeft, .bottomRight, .center, .fill] {
            let r = frame(placement, half, in: zero)
            XCTAssertEqual(r.size, .zero, "\(placement)")
        }
    }
}
