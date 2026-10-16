import XCTest
import WindowCore

final class AccessibilityGateTests: XCTestCase {
    func testTransitions() {
        var gate = AccessibilityGate()
        XCTAssertNil(gate.state)
        XCTAssertNil(gate.update(trusted: false))
        XCTAssertEqual(gate.state, .denied)
        XCTAssertEqual(gate.update(trusted: true), .becameGranted)
        XCTAssertNil(gate.update(trusted: true))
        XCTAssertEqual(gate.update(trusted: false), .becameRevoked)
        XCTAssertEqual(gate.state, .denied)

        var fresh = AccessibilityGate()
        XCTAssertEqual(fresh.update(trusted: true), .becameGranted)
        XCTAssertEqual(fresh.state, .granted)
    }

    func testPollInterval() {
        XCTAssertEqual(AccessibilityGate.pollInterval(for: .denied), 2.0)
        XCTAssertEqual(AccessibilityGate.pollInterval(for: .granted), 10.0)
    }
}
