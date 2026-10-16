import Foundation

/// 손쉬운 사용 권한 상태.
public enum PermissionState: Equatable {
    case granted
    case denied
}

/// 앱에 끼우는 기능 1개. `FeatureRegistry`가 권한 상태에 맞춰 시작/정지한다.
public protocol AppFeature: AnyObject {
    var featureID: String { get }
    /// true면 손쉬운 사용 권한이 있을 때만 시작한다.
    var requiresAccessibility: Bool { get }
    func start() throws
    func stop()
}
