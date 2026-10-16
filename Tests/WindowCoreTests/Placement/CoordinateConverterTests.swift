import CoreGraphics
import XCTest
import WindowCore

final class CoordinateConverterTests: XCTestCase {
    private let primaryHeight: CGFloat = 900

    func testRoundTrip() {
        let rects = [
            CGRect(x: 0, y: 0, width: 1440, height: 900),
            CGRect(x: 12, y: 34, width: 560, height: 780),
            CGRect(x: -1920, y: -500, width: 1920, height: 1080),
            CGRect(x: 1440, y: -180, width: 1920, height: 1080),
            CGRect(x: -300.5, y: 900, width: 800.25, height: 600.75),
        ]
        for r in rects {
            XCTAssertEqual(CoordinateConverter.toCocoa(CoordinateConverter.toAX(r, primaryHeight: primaryHeight),
                                                       primaryHeight: primaryHeight), r)
        }
    }

    func testPrimaryVisibleArea() {
        XCTAssertEqual(CoordinateConverter.toAX(CGRect(x: 0, y: 0, width: 1440, height: 875), primaryHeight: primaryHeight),
                       CGRect(x: 0, y: 25, width: 1440, height: 875))
    }

    func testScreenAbovePrimary() {
        XCTAssertEqual(CoordinateConverter.toAX(CGRect(x: 0, y: 900, width: 1920, height: 1080), primaryHeight: primaryHeight),
                       CGRect(x: 0, y: -1080, width: 1920, height: 1080))
    }

    func testScreenRightOfPrimary() {
        XCTAssertEqual(CoordinateConverter.toAX(CGRect(x: 1440, y: -180, width: 1920, height: 1080), primaryHeight: primaryHeight),
                       CGRect(x: 1440, y: 0, width: 1920, height: 1080))
    }

    func testScreenLeftBelowPrimary() {
        XCTAssertEqual(CoordinateConverter.toAX(CGRect(x: -1920, y: -500, width: 1920, height: 1080), primaryHeight: primaryHeight),
                       CGRect(x: -1920, y: 320, width: 1920, height: 1080))
    }
}
