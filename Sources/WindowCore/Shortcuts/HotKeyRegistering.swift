import Foundation

/// 전역 단축키 등록기. 실행 타깃의 `CarbonHotKeyRegistrar`가 구현하고, 테스트는 가짜 구현을 쓴다.
/// 메인 스레드에서만 호출한다.
public protocol HotKeyRegistering: AnyObject {
    /// 등록한 단축키가 눌리면 그 번호로 호출된다(누를 때만).
    var onHotKey: ((UInt32) -> Void)? { get set }
    /// 실패하면 false. 이미 있는 번호면 먼저 해제하고 다시 등록한다.
    func register(_ combo: KeyCombo, id: UInt32) -> Bool
    func unregister(id: UInt32)
    func unregisterAll()
}
