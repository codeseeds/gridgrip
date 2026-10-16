import CoreGraphics
import XCTest
import WindowCore

final class SizeConstraintAdjusterTests: XCTestCase {
    private let vf = PlacementFixtures.vf

    func testRightKeepsRightEdge() {
        XCTAssertEqual(SizeConstraintAdjuster.adjust(target: CGRect(x: 800, y: 30, width: 400, height: 900),
                                                     actualSize: CGSize(width: 500, height: 900), placement: .right, in: vf),
                       CGRect(x: 700, y: 30, width: 500, height: 900))
    }

    func testBottomRightKeepsBothEdges() {
        XCTAssertEqual(SizeConstraintAdjuster.adjust(target: CGRect(x: 800, y: 630, width: 400, height: 300),
                                                     actualSize: CGSize(width: 500, height: 400), placement: .bottomRight, in: vf),
                       CGRect(x: 700, y: 530, width: 500, height: 400))
    }

    func testBottomKeepsBottomEdge() {
        XCTAssertEqual(SizeConstraintAdjuster.adjust(target: CGRect(x: 0, y: 630, width: 1200, height: 300),
                                                     actualSize: CGSize(width: 1200, height: 400), placement: .bottom, in: vf),
                       CGRect(x: 0, y: 530, width: 1200, height: 400))
    }

    func testLeftAndTopAnchoredKeepOrigin() {
        let actual = CGSize(width: 700, height: 500)
        let cases: [(Placement, CGRect)] = [
            (.topLeft, CGRect(x: 0, y: 30, width: 400, height: 300)),
            (.left, CGRect(x: 0, y: 30, width: 400, height: 900)),
            (.top, CGRect(x: 0, y: 30, width: 1200, height: 300)),
        ]
        for (placement, target) in cases {
            let result = SizeConstraintAdjuster.adjust(target: target, actualSize: actual, placement: placement, in: vf)
            XCTAssertEqual(result.origin, target.origin, "\(placement)")
            XCTAssertEqual(result.size, actual, "\(placement)")
        }
    }

    func testCenterRecenters() {
        XCTAssertEqual(SizeConstraintAdjuster.adjust(target: CGRect(x: 350, y: 280, width: 500, height: 400),
                                                     actualSize: CGSize(width: 600, height: 500), placement: .center, in: vf),
                       CGRect(x: 300, y: 230, width: 600, height: 500))
    }

    func testOversizedAlignsTopLeft() {
        let actual = CGSize(width: 1300, height: 1000)
        for placement in [Placement.right, .bottomRight, .center, .left] {
            let result = SizeConstraintAdjuster.adjust(target: CGRect(x: 800, y: 630, width: 400, height: 300),
                                                       actualSize: actual, placement: placement, in: vf)
            XCTAssertEqual(result.origin, CGPoint(x: 0, y: 30), "\(placement)")
        }
    }

    // 모니터 이동 시 실제 크기 기준으로 visibleFrame 안으로 밀어 넣기
    func testFitPushesInsideAndAlignsTopLeftWhenOversized() {
        XCTAssertEqual(SizeConstraintAdjuster.fit(target: CGRect(x: 720, y: 25, width: 720, height: 875),
                                                  actualSize: CGSize(width: 1000, height: 875), in: PlacementFixtures.a.visibleFrame),
                       CGRect(x: 440, y: 25, width: 1000, height: 875))
        XCTAssertEqual(SizeConstraintAdjuster.fit(target: CGRect(x: 100, y: 100, width: 200, height: 200),
                                                  actualSize: CGSize(width: 1300, height: 1000), in: vf).origin,
                       CGPoint(x: 0, y: 30))
        XCTAssertEqual(SizeConstraintAdjuster.fit(target: CGRect(x: -50, y: 0, width: 200, height: 200),
                                                  actualSize: CGSize(width: 200, height: 200), in: vf).origin,
                       CGPoint(x: 0, y: 30))
    }
}
