import Foundation

/// 단축키·메뉴로 실행하는 동작 14종.
/// raw value는 저장 키이므로 바꾸지 않는다. 선언 순서 = 메뉴·설정 창 순서 = 핫키 번호 기준.
public enum WindowAction: String, CaseIterable, Codable {
    case topLeft, top, topRight
    case left, center, right
    case bottomLeft, bottom, bottomRight
    case fill
    case previousDisplay, nextDisplay
    case undo, redo

    /// 선언 인덱스 + 1 (1~14).
    public var hotKeyID: UInt32 {
        UInt32(Self.allCases.firstIndex(of: self)! + 1)
    }

    /// 1~14가 아니면 nil.
    public init?(hotKeyID: UInt32) {
        let cases = Self.allCases
        guard hotKeyID >= 1, hotKeyID <= UInt32(cases.count) else { return nil }
        self = cases[Int(hotKeyID) - 1]
    }
}
