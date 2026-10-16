import Foundation

/// 단축키가 겹칠 수 있는 원본 창 관리 앱 (읽기 전용 참조 — 번들 ID만 사용).
public struct KnownConflictingApp: Equatable {
    public let bundleIdentifier: String
    public let displayName: String

    public init(bundleIdentifier: String, displayName: String) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
    }

    public static let windowMover = KnownConflictingApp(bundleIdentifier: "de.curioustimes.Window-Mover", displayName: "Window Mover")
    public static let spectacle = KnownConflictingApp(bundleIdentifier: "com.divisiblebyzero.Spectacle", displayName: "Spectacle")
    public static let all: [KnownConflictingApp] = [windowMover, spectacle]
}

public enum ConflictNoticePolicy {
    /// 실행 중인 원본 앱 (`KnownConflictingApp.all` 순서).
    public static func conflicts(runningBundleIDs: [String]) -> [KnownConflictingApp] {
        let running = Set(runningBundleIDs)
        return KnownConflictingApp.all.filter { running.contains($0.bundleIdentifier) }
    }

    /// 최초 실행 점검 전이고 원본 앱이 실행 중일 때만 안내한다.
    public static func shouldShowNotice(conflicts: [KnownConflictingApp], alreadyChecked: Bool) -> Bool {
        !alreadyChecked && !conflicts.isEmpty
    }
}
