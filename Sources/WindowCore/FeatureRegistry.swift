import Foundation

public enum FeatureRegistryError: Error, Equatable {
    case duplicateID(String)
    case registrationClosed
}

/// 등록된 기능을 권한 상태에 맞춰 시작/정지한다.
/// 메인 스레드에서만 사용한다.
public final class FeatureRegistry {
    private var features: [AppFeature] = []
    private var running: Set<String> = []
    private var failed: Set<String> = []
    private var isRegistrationClosed = false

    /// 기능 `start()`가 throw할 때마다 호출된다. 실행 타깃이 로그를 남기는 훅.
    public var onStartFailure: ((_ featureID: String, _ error: Error) -> Void)?

    public init() {}

    /// 실행 중인 기능 ID (등록 순서).
    public var runningFeatureIDs: [String] {
        features.map(\.featureID).filter { running.contains($0) }
    }

    /// 시작에 실패해 다음 `apply`에서 재시도할 기능 ID (등록 순서).
    public var failedFeatureIDs: [String] {
        features.map(\.featureID).filter { failed.contains($0) }
    }

    /// (R1) 첫 `apply` 전에만 허용한다.
    public func register(_ feature: AppFeature) throws {
        guard !isRegistrationClosed else { throw FeatureRegistryError.registrationClosed }
        guard !features.contains(where: { $0.featureID == feature.featureID }) else {
            throw FeatureRegistryError.duplicateID(feature.featureID)
        }
        features.append(feature)
    }

    public func apply(permission: PermissionState) {
        isRegistrationClosed = true

        if permission == .denied {
            // (R6) 권한 필요 기능은 역순 정지하고, 권한 대기 상태로 보아 실패 목록에서도 뺀다.
            for feature in features.reversed() where feature.requiresAccessibility {
                let id = feature.featureID
                failed.remove(id)
                if running.remove(id) != nil {
                    feature.stop()
                }
            }
        }

        // (R4·R5) 실행 중이 아닌 기능만 등록 순서대로 시작(실패 기능 재시도 포함).
        for feature in features where !running.contains(feature.featureID) {
            if permission == .denied && feature.requiresAccessibility { continue }
            let id = feature.featureID
            do {
                try feature.start()
                running.insert(id)
                failed.remove(id)
            } catch {
                failed.insert(id)
                onStartFailure?(id, error)
            }
        }
    }

    /// 실행 중 기능을 등록 역순으로 정지하고 실패 목록을 비운다.
    public func stopAll() {
        for feature in features.reversed() where running.contains(feature.featureID) {
            feature.stop()
        }
        running.removeAll()
        failed.removeAll()
    }
}
