import XCTest
import WindowCore

final class KeyComboTests: XCTestCase {
    func testDisplayString() {
        XCTAssertEqual(KeyCombo(keyCode: 0x04, modifiers: [.command, .shift, .option]).displayString, "⌥⇧⌘H")
        XCTAssertEqual(KeyCombo(keyCode: 0x06, modifiers: [.control, .option, .command]).displayString, "⌃⌥⌘Z")
        XCTAssertEqual(KeyCombo(keyCode: 0x2B, modifiers: [.shift, .option, .command]).displayString, "⌥⇧⌘,")
        XCTAssertEqual(KeyCombo(keyCode: 0x2F, modifiers: [.shift, .option, .command]).displayString, "⌥⇧⌘.")
        XCTAssertEqual(KeyCombo(keyCode: 0x7F, modifiers: [.shift, .option, .command]).displayString, "⌥⇧⌘Key 0x7F")
    }

    func testCarbonModifierFlags() {
        XCTAssertEqual(KeyCombo(keyCode: 0x04, modifiers: [.shift, .option, .command]).carbonModifierFlags, 0x0B00)
        XCTAssertEqual(KeyCombo(keyCode: 0x04, modifiers: [.control]).carbonModifierFlags, 0x1000)
        XCTAssertEqual(KeyCombo(keyCode: 0x04, modifiers: [.option, .command]).carbonModifierFlags, 0x0900)
    }

    func testCodableRoundTrip() throws {
        let combo = KeyCombo(keyCode: 0x25, modifiers: [.control, .option, .command])
        let data = try JSONEncoder().encode(combo)
        XCTAssertEqual(try JSONDecoder().decode(KeyCombo.self, from: data), combo)

        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["keyCode"] as? Int, 0x25)
        let modifiers = try XCTUnwrap(object["modifiers"] as? [String])
        XCTAssertEqual(Set(modifiers), ["control", "option", "command"])
    }
}
