import CoreGraphics
import XCTest
import WindowCore

final class MouseDragRecordDecisionTests: XCTestCase {
    private let initial = CGRect(x: 100, y: 200, width: 800, height: 600)

    private func session(_ action: MouseAction) -> MouseDragSession<Int> {
        MouseDragSession(window: 1, action: action, initialFrame: initial)
    }

    func testRecordsActualFrameWhenChanged() throws {
        let actual = CGRect(x: 100, y: 200, width: 640, height: 480)
        let record = try XCTUnwrap(MouseDragRecordDecision.make(session: session(.resize), readResult: .success(actual)))
        XCTAssertEqual(record.before, initial)
        XCTAssertEqual(record.after, actual)
        XCTAssertEqual(record.source, .mouseResize)
    }

    func testNoRecordWhenWithinTolerance() {
        let nearly = CGRect(x: 101, y: 201, width: 800, height: 600)
        XCTAssertNil(MouseDragRecordDecision.make(session: session(.move), readResult: .success(nearly)))
    }

    func testNoRecordWhenWindowGone() {
        XCTAssertNil(MouseDragRecordDecision.make(session: session(.move), readResult: .failure(.windowGone)))
    }

    func testNoRecordOnOtherReadFailures() {
        XCTAssertNil(MouseDragRecordDecision.make(session: session(.move), readResult: .failure(.timedOut)))
        XCTAssertNil(MouseDragRecordDecision.make(session: session(.move), readResult: .failure(.failed(code: -25211))))
    }
}
