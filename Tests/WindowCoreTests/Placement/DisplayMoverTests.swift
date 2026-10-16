import CoreGraphics
import XCTest
import WindowCore

final class DisplayMoverTests: XCTestCase {
    private let a = PlacementFixtures.a
    private let b = PlacementFixtures.b
    private let c = PlacementFixtures.c

    func testOrdering() {
        XCTAssertEqual(DisplayMover.orderedScreens([b, a, c]), [c, a, b])

        let upper = ScreenGeometry(frame: CGRect(x: 0, y: -1080, width: 1920, height: 1080),
                                   visibleFrame: CGRect(x: 0, y: -1080, width: 1920, height: 1080))
        XCTAssertEqual(DisplayMover.orderedScreens([a, upper]), [upper, a])
    }

    func testKeepsRelativePositionAndSize() {
        let window = CGRect(x: 360, y: 200, width: 360, height: 350)
        XCTAssertEqual(DisplayMover.target(window: window, from: a, screens: [a, b], direction: .next),
                       CGRect(x: 1920, y: 216, width: 480, height: 432))
    }

    func testLeftHalfToNext() {
        let window = CGRect(x: 0, y: 25, width: 720, height: 875)
        XCTAssertEqual(DisplayMover.target(window: window, from: a, screens: [a, b], direction: .next),
                       CGRect(x: 1440, y: 0, width: 960, height: 1080))
    }

    func testWrapsAtEnds() {
        let screens = [c, a, b]
        let onB = CGRect(x: 1500, y: 100, width: 800, height: 600)
        let fromB = DisplayMover.target(window: onB, from: b, screens: screens, direction: .next)
        XCTAssertNotNil(fromB)
        XCTAssertTrue(c.visibleFrame.contains(fromB!), "\(String(describing: fromB))")

        let onC = CGRect(x: -1800, y: 400, width: 800, height: 600)
        let fromC = DisplayMover.target(window: onC, from: c, screens: screens, direction: .previous)
        XCTAssertNotNil(fromC)
        XCTAssertTrue(b.visibleFrame.contains(fromC!), "\(String(describing: fromC))")
    }

    func testPreviousFromPrimaryIsLeft() {
        let onA = CGRect(x: 100, y: 100, width: 400, height: 300)
        let result = DisplayMover.target(window: onA, from: a, screens: [b, a, c], direction: .previous)
        XCTAssertNotNil(result)
        XCTAssertTrue(c.visibleFrame.contains(result!), "\(String(describing: result))")
    }

    // 
    func testSingleScreenIsNil() {
        XCTAssertNil(DisplayMover.target(window: CGRect(x: 0, y: 25, width: 720, height: 875), from: a, screens: [a], direction: .next))
    }

    func testOversizedWindowIsClampedIntoTarget() {
        let wide = CGRect(x: -100, y: 25, width: 1640, height: 875)
        let result = DisplayMover.target(window: wide, from: a, screens: [a, b], direction: .next)
        XCTAssertNotNil(result)
        XCTAssertTrue(b.visibleFrame.contains(result!), "\(String(describing: result))")

        let tall = CGRect(x: -1900, y: 300, width: 500, height: 1200)
        let toA = DisplayMover.target(window: tall, from: c, screens: [c, a], direction: .next)
        XCTAssertNotNil(toA)
        XCTAssertTrue(a.visibleFrame.contains(toA!), "\(String(describing: toA))")
    }
}
