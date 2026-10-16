import CoreGraphics
import XCTest
import WindowCore

final class ScreenSelectorTests: XCTestCase {
    private let a = PlacementFixtures.a
    private let b = PlacementFixtures.b
    private let c = PlacementFixtures.c

    func testLargestIntersectionWins() {
        let window = CGRect(x: 1300, y: 100, width: 800, height: 600)
        XCTAssertEqual(ScreenSelector.screen(for: window, among: [a, b, c]), b)
    }

    func testNoIntersectionPicksNearestCenter() {
        let window = CGRect(x: 5000, y: 5000, width: 100, height: 100)
        XCTAssertEqual(ScreenSelector.screen(for: window, among: [a, b, c]), b)
    }

    func testSingleScreenOffscreenWindow() {
        let window = CGRect(x: -9000, y: -9000, width: 100, height: 100)
        XCTAssertEqual(ScreenSelector.screen(for: window, among: [a]), a)
    }

    // 
    func testEmptyScreensIsNil() {
        XCTAssertNil(ScreenSelector.screen(for: CGRect(x: 0, y: 0, width: 10, height: 10), among: []))
    }
}
