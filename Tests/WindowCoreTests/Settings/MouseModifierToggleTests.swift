import XCTest
import WindowCore

final class MouseModifierToggleTests: XCTestCase {
    func testRejects() throws {
        let base = MouseDragSettings.default

        let first = MouseModifierToggle.apply(base, target: .move, modifier: .control, isOn: false)
        guard case let .accepted(moveFnOnly) = first else { return XCTFail("\(first)") }
        XCTAssertEqual(moveFnOnly.moveModifiers, [.fn])

        let second = MouseModifierToggle.apply(moveFnOnly, target: .move, modifier: .fn, isOn: false)
        XCTAssertEqual(second, .rejected(.emptyMoveModifiers))
        XCTAssertEqual(moveFnOnly.moveModifiers, [.fn])

        let resizeFn = MouseModifierToggle.apply(base, target: .resize, modifier: .option, isOn: false)
        guard case let .accepted(resizeFnOnly) = resizeFn else { return XCTFail("\(resizeFn)") }
        let identical = MouseModifierToggle.apply(resizeFnOnly, target: .resize, modifier: .control, isOn: true)
        XCTAssertEqual(identical, .rejected(.identicalModifiers))
        XCTAssertEqual(resizeFnOnly.resizeModifiers, [.fn])
    }

    func testAccepts() {
        let result = MouseModifierToggle.apply(.default, target: .move, modifier: .shift, isOn: true)
        XCTAssertEqual(result, .accepted(MouseDragSettings(moveModifiers: [.shift, .fn, .control],
                                                           resizeModifiers: [.fn, .option],
                                                           bringWindowToFront: true)))
    }
}
