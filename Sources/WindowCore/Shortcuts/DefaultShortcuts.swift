import Foundation

/// 기본 단축키 14종. 배치 12종은 ⇧⌥⌘ + 키, 되돌리기 ⌥⌘Z / 다시하기 ⇧⌥⌘Z(사용자 확정).
public enum DefaultShortcuts {
    public static let bindings: ShortcutBindings = {
        let hyper: ModifierSet = [.shift, .option, .command]
        return ShortcutBindings([
            .topLeft: KeyCombo(keyCode: 0x10, modifiers: hyper),          // Y
            .top: KeyCombo(keyCode: 0x20, modifiers: hyper),              // U
            .topRight: KeyCombo(keyCode: 0x22, modifiers: hyper),         // I
            .left: KeyCombo(keyCode: 0x04, modifiers: hyper),             // H
            .center: KeyCombo(keyCode: 0x26, modifiers: hyper),           // J
            .right: KeyCombo(keyCode: 0x28, modifiers: hyper),            // K
            .bottomLeft: KeyCombo(keyCode: 0x0B, modifiers: hyper),       // B
            .bottom: KeyCombo(keyCode: 0x2D, modifiers: hyper),           // N
            .bottomRight: KeyCombo(keyCode: 0x2E, modifiers: hyper),      // M
            .fill: KeyCombo(keyCode: 0x03, modifiers: hyper),             // F
            .previousDisplay: KeyCombo(keyCode: 0x2B, modifiers: hyper),  // ,
            .nextDisplay: KeyCombo(keyCode: 0x2F, modifiers: hyper),      // .
            .undo: KeyCombo(keyCode: 0x06, modifiers: [.option, .command]),  // Z
            .redo: KeyCombo(keyCode: 0x06, modifiers: hyper),             // Z
        ])
    }()
}
