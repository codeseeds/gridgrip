import XCTest
import WindowCore

final class ActionDispatcherTests: XCTestCase {
    func testDispatchWithoutHandlerReturnsFalse() {
        XCTAssertFalse(ActionDispatcher().dispatch(.undo))
    }

    func testHandlerReplacement() {
        let dispatcher = ActionDispatcher()
        var calls: [String] = []
        dispatcher.setHandler(for: [.fill]) { _ in calls.append("A") }
        dispatcher.setHandler(for: [.fill]) { _ in calls.append("B") }

        XCTAssertTrue(dispatcher.dispatch(.fill))
        XCTAssertEqual(calls, ["B"])

        dispatcher.removeHandler(for: [.fill])
        XCTAssertFalse(dispatcher.dispatch(.fill))
        XCTAssertEqual(calls, ["B"])
    }

    func testShouldDispatchGate() {
        let dispatcher = ActionDispatcher()
        var received: [WindowAction] = []
        dispatcher.setHandler(for: [.left, .undo]) { received.append($0) }

        dispatcher.shouldDispatch = { _ in false }
        XCTAssertFalse(dispatcher.dispatch(.left))
        XCTAssertEqual(received, [])

        dispatcher.shouldDispatch = { $0 == .undo }
        XCTAssertFalse(dispatcher.dispatch(.left))
        XCTAssertTrue(dispatcher.dispatch(.undo))
        XCTAssertEqual(received, [.undo])

        dispatcher.shouldDispatch = nil
        XCTAssertTrue(dispatcher.dispatch(.left))
        XCTAssertEqual(received, [.undo, .left])
    }
}
