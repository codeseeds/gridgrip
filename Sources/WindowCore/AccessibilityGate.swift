import Foundation

public enum PermissionTransition: Equatable {
    case becameGranted
    case becameRevoked
}

/// 권한 상태 전환 감지와 점검 주기 정책.
/// 전환 값은 점검 주기·로그·메뉴 재구성에만 쓴다(기능 시작/정지 판단에 쓰지 않음).
public struct AccessibilityGate {
    public private(set) var state: PermissionState?

    public init() {}

    /// 첫 호출이 trusted면 `.becameGranted`, 아니면 `nil`(상태는 `.denied`로 기록).
    @discardableResult
    public mutating func update(trusted: Bool) -> PermissionTransition? {
        let newState: PermissionState = trusted ? .granted : .denied
        let previous = state
        state = newState
        switch (previous, newState) {
        case (nil, .granted), (.denied?, .granted):
            return .becameGranted
        case (.granted?, .denied):
            return .becameRevoked
        default:
            return nil
        }
    }

    public static func pollInterval(for state: PermissionState) -> TimeInterval {
        switch state {
        case .denied: return 2.0
        case .granted: return 10.0
        }
    }
}
