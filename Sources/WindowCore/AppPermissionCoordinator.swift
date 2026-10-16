import Foundation

public struct AppPermissionCheck: Equatable {
    public let state: PermissionState
    public let transition: PermissionTransition?
    public let nextInterval: TimeInterval
    /// 전환이 있었으면 true.
    public let needsMenuRebuild: Bool

    public init(state: PermissionState, transition: PermissionTransition?, nextInterval: TimeInterval, needsMenuRebuild: Bool) {
        self.state = state
        self.transition = transition
        self.nextInterval = nextInterval
        self.needsMenuRebuild = needsMenuRebuild
    }
}

/// 권한 점검 ↔ 기능 등록부 연결.
/// 시작 직후 1회와 주기 점검마다 `check`를 부른다. 메인 스레드에서만 사용한다.
public final class AppPermissionCoordinator {
    private let registry: FeatureRegistry
    private var gate: AccessibilityGate

    /// 가장 최근 `check` 결과의 상태. 점검 전에는 nil.
    public var state: PermissionState? { gate.state }

    public init(registry: FeatureRegistry, gate: AccessibilityGate = AccessibilityGate()) {
        self.registry = registry
        self.gate = gate
    }

    /// 전환 유무와 무관하게 항상 `registry.apply`를 부른다 — 실패한 기능의 재시도 기회.
    @discardableResult
    public func check(trusted: Bool) -> AppPermissionCheck {
        let transition = gate.update(trusted: trusted)
        let state: PermissionState = trusted ? .granted : .denied
        registry.apply(permission: state)
        return AppPermissionCheck(
            state: state,
            transition: transition,
            nextInterval: AccessibilityGate.pollInterval(for: state),
            needsMenuRebuild: transition != nil
        )
    }
}
