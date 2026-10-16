import Foundation

/// 제외 앱 추가 결과.
public enum SettingsExcludeAddResult: Equatable {
    case added
    case duplicate
    case rejectedSelf
    case rejectedEmpty
}

/// 일시정지·제외 앱 값과 편집 규칙. 번들 ID는 입력한 대소문자 그대로 두고 비교만 대소문자 무시로 한다
/// (`ActivationPolicy.isExcluded`와 같은 규칙). 메모리 상태의 정본은 `ActivationPolicy`, 이 타입은 스냅샷·편집용이다.
public struct GeneralSettings: Codable, Equatable {
    /// 로드 시 상한(조작된 저장값으로 비교가 느려지는 것 방지).
    public static let maxExcludedCount = 500
    public static let maxBundleIDLength = 255

    public var isPaused: Bool
    public var excludedBundleIDs: [String]

    public init(isPaused: Bool = false, excludedBundleIDs: [String] = []) {
        self.isPaused = isPaused
        self.excludedBundleIDs = excludedBundleIDs
    }

    /// 현재 `ActivationPolicy` 값의 스냅샷.
    public init(policy: ActivationPolicy) {
        self.init(isPaused: policy.isPaused, excludedBundleIDs: policy.excludedBundleIDs)
    }

    /// 있으면 빼고 없으면 넣는다. 빈 ID·우리 앱 자신이면 바꾸지 않고 false.
    @discardableResult
    public mutating func toggleExcluded(_ id: String, selfBundleID: String) -> Bool {
        if contains(id) {
            removeExcluded(id)
            return true
        }
        return addExcluded(id, selfBundleID: selfBundleID) == .added
    }

    /// 추가 전용. 중복(대소문자 무시)·우리 앱 자신·빈 ID는 거부한다.
    @discardableResult
    public mutating func addExcluded(_ id: String, selfBundleID: String) -> SettingsExcludeAddResult {
        guard !id.isEmpty else { return .rejectedEmpty }
        guard !Self.same(id, selfBundleID) else { return .rejectedSelf }
        guard !contains(id) else { return .duplicate }
        excludedBundleIDs.append(id)
        return .added
    }

    public mutating func removeExcluded(_ id: String) {
        excludedBundleIDs.removeAll { Self.same($0, id) }
    }

    /// 로드 정리: 빈 문자열·255자 초과·우리 앱 자신 제거 + 대소문자 무시 중복 제거(처음 등장 순서 유지) + 앞에서 500개까지.
    public static func sanitized(_ ids: [String], selfBundleID: String) -> [String] {
        var result: [String] = []
        for id in ids where result.count < maxExcludedCount {
            guard !id.isEmpty, id.count <= maxBundleIDLength, !same(id, selfBundleID),
                  !result.contains(where: { same($0, id) }) else { continue }
            result.append(id)
        }
        return result
    }

    private func contains(_ id: String) -> Bool {
        excludedBundleIDs.contains { Self.same($0, id) }
    }

    private static func same(_ a: String, _ b: String) -> Bool {
        a.caseInsensitiveCompare(b) == .orderedSame
    }
}
