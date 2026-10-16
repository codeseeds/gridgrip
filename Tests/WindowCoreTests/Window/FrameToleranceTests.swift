import CoreGraphics
import XCTest
import WindowCore

final class FrameToleranceTests: XCTestCase {
    func testIsSameBoundary() {
        XCTAssertEqual(FrameTolerance.points, 2)
        let base = CGRect(x: 0, y: 0, width: 100, height: 100)
        XCTAssertTrue(FrameTolerance.isSame(base, CGRect(x: 2, y: -2, width: 102, height: 98)))
        XCTAssertFalse(FrameTolerance.isSame(base, CGRect(x: 2.01, y: 0, width: 100, height: 100)))
        XCTAssertFalse(FrameTolerance.isSame(base, CGRect(x: 0, y: 0, width: 100, height: 102.5)))
    }
}
