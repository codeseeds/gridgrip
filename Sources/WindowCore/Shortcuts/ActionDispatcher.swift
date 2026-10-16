import Foundation

/// 동작 → 핸들러 전달. 단축키와 메뉴 클릭이 같은 `dispatch`를 쓴다.
/// 제외 앱 판정은 여기서 하지 않는다. 메인 스레드에서만 사용한다.
public final class ActionDispatcher {
    /// nil이면 통과. false를 돌려주면 핸들러를 부르지 않는다(일시정지 거르기).
    public var shouldDispatch: ((WindowAction) -> Bool)?
    private var handlers: [WindowAction: (WindowAction) -> Void] = [:]

    public init() {}

    /// 동작당 핸들러 1개. 이미 있으면 교체한다.
    public func setHandler(for actions: [WindowAction], _ handler: @escaping (WindowAction) -> Void) {
        for action in actions {
            handlers[action] = handler
        }
    }

    public func removeHandler(for actions: [WindowAction]) {
        for action in actions {
            handlers[action] = nil
        }
    }

    /// 핸들러를 실행했으면 true. 거르기에 막히거나 핸들러가 없으면 false.
    @discardableResult
    public func dispatch(_ action: WindowAction) -> Bool {
        if let shouldDispatch, !shouldDispatch(action) { return false }
        guard let handler = handlers[action] else { return false }
        handler(action)
        return true
    }
}
