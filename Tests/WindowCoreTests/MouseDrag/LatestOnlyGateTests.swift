import XCTest
import WindowCore

final class LatestOnlyGateTests: XCTestCase {
    func testSubmitIntoEmptySlotRequestsDrain() {
        var gate = LatestOnlyGate<Int>()
        XCTAssertTrue(gate.submit(1))
        XCTAssertTrue(gate.hasPending)
        XCTAssertEqual(gate.takeLatest(), 1)
        XCTAssertFalse(gate.hasPending)
    }

    func testSubmitWhilePendingKeepsOnlyLatest() {
        var gate = LatestOnlyGate<Int>()
        XCTAssertTrue(gate.submit(1))
        XCTAssertFalse(gate.submit(2))
        XCTAssertFalse(gate.submit(3))
        XCTAssertEqual(gate.takeLatest(), 3)
        XCTAssertNil(gate.takeLatest())
    }

    func testSubmitAfterTakeRequestsDrainAgain() {
        var gate = LatestOnlyGate<Int>()
        _ = gate.submit(1)
        _ = gate.takeLatest()
        XCTAssertTrue(gate.submit(5))
        XCTAssertEqual(gate.takeLatest(), 5)
    }
}
