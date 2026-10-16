import Foundation

/// 전역 단축키 기능 단위. 권한이 없으면 `FeatureRegistry`가 시작하지 않으므로
/// 창을 못 움직이는데 키만 가로채는 상태가 생기지 않는다.
public final class ShortcutsFeature: AppFeature {
    public let featureID = "shortcuts"
    public let requiresAccessibility = true
    private let engine: ShortcutEngine

    public init(engine: ShortcutEngine) {
        self.engine = engine
    }

    /// 개별 등록 실패는 throw하지 않는다(다른 앱 선점이 원인이라 재시도로 해결되지 않음 → `registrationFailures`로 알림).
    public func start() throws {
        engine.start()
    }

    public func stop() {
        engine.stop()
    }
}
