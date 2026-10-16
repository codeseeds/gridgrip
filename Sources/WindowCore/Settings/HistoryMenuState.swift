import Foundation

/// 되돌리기/다시하기 메뉴 활성 값 제공 지점. 되돌리기 기능이 `installUndo`에서 클로저를 바꾼다.
/// 그 전에는 항상 켜져 있고, 눌러도 핸들러가 없어 아무 일 없다.
public final class HistoryMenuState {
    public var canUndo: () -> Bool = { true }
    public var canRedo: () -> Bool = { true }

    public init() {}
}
