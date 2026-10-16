import Foundation

/// 잠시 끄기·앱 제외의 메모리 상태. 저장·UI는 설정 기능이 맡는다.
/// 메인 스레드에서만 읽고 쓴다.
public final class ActivationPolicy {
    public private(set) var isPaused: Bool
    /// 입력 순서 유지. 정규화·중복 제거는 하지 않는다(설정 기능 책임).
    public private(set) var excludedBundleIDs: [String]
    private var observers: [() -> Void] = []

    public init(isPaused: Bool = false, excludedBundleIDs: [String] = []) {
        self.isPaused = isPaused
        self.excludedBundleIDs = excludedBundleIDs
    }

    /// nil → false. 대소문자를 무시해 비교한다.
    public func isExcluded(bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else { return false }
        return excludedBundleIDs.contains { $0.caseInsensitiveCompare(bundleIdentifier) == .orderedSame }
    }

    /// 실제 값이 바뀔 때만 반영하고, 한 번의 호출에 관찰자를 등록 순서대로 최대 1회씩 부른다.
    public func update(isPaused: Bool? = nil, excludedBundleIDs: [String]? = nil) {
        var changed = false
        if let isPaused, isPaused != self.isPaused {
            self.isPaused = isPaused
            changed = true
        }
        if let excludedBundleIDs, excludedBundleIDs != self.excludedBundleIDs {
            self.excludedBundleIDs = excludedBundleIDs
            changed = true
        }
        guard changed else { return }
        observers.forEach { $0() }
    }

    public func addObserver(_ handler: @escaping () -> Void) {
        observers.append(handler)
    }
}
