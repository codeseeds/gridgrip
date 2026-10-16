import XCTest
import WindowCore

final class PlacementCommandTests: XCTestCase {
    func testTwelveActionsMapToCommands() {
        let expected: [WindowAction: PlacementCommand] = [
            .topLeft: .place(.topLeft),
            .top: .place(.top),
            .topRight: .place(.topRight),
            .left: .place(.left),
            .center: .place(.center),
            .right: .place(.right),
            .bottomLeft: .place(.bottomLeft),
            .bottom: .place(.bottom),
            .bottomRight: .place(.bottomRight),
            .fill: .place(.fill),
            .previousDisplay: .moveToDisplay(.previous),
            .nextDisplay: .moveToDisplay(.next),
        ]
        XCTAssertEqual(expected.count, 12)
        for (action, command) in expected {
            XCTAssertEqual(PlacementCommand(action: action), command, action.rawValue)
        }
    }

    func testUndoRedoExcludedAndHandledActions() {
        XCTAssertNil(PlacementCommand(action: .undo))
        XCTAssertNil(PlacementCommand(action: .redo))

        let handled = PlacementCommand.handledActions
        XCTAssertEqual(handled.count, 12)
        XCTAssertFalse(handled.contains(.undo))
        XCTAssertFalse(handled.contains(.redo))
        for action in handled {
            XCTAssertNotNil(PlacementCommand(action: action), action.rawValue)
        }
        XCTAssertEqual(handled, WindowAction.allCases.filter { $0 != .undo && $0 != .redo })
    }
}
