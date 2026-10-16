import Foundation

/// UserDefaults 키 `general.v1`에 일시정지·제외 앱을 저장·로드한다. 이 키 외에는 읽고 쓰지 않는다.
/// 형식: `{"version":1,"isPaused":false,"excludedBundleIDs":["com.apple.dt.Xcode"]}`
/// `AppContext.shared`(AnyObject 제약)에 넣기 위해 class로 둔다.
public final class GeneralSettingsStore {
    public static let key = "general.v1"
    private static let version = 1

    /// 직전 `load()`가 손상 데이터를 기본값으로 대체했으면 true. 로그는 실행 타깃이 찍는다(WindowCore는 `os` import 금지).
    public private(set) var lastLoadRecovered = false
    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    /// 저장값 없음 → 기본값. 손상·디코딩 실패·버전 불일치 → 기본값(크래시 없음). 제외 목록은 `GeneralSettings.sanitized`로 정리한다.
    public func load() -> GeneralSettings {
        lastLoadRecovered = false
        guard let object = defaults.object(forKey: Self.key) else { return GeneralSettings() }
        guard let data = object as? Data,
              let file = try? JSONDecoder().decode(StoredFile.self, from: data),
              file.version == Self.version
        else {
            lastLoadRecovered = true
            return GeneralSettings()
        }
        let excluded = GeneralSettings.sanitized(file.excludedBundleIDs, selfBundleID: AppIdentity.bundleIdentifier)
        return GeneralSettings(isPaused: file.isPaused, excludedBundleIDs: excluded)
    }

    public func save(_ settings: GeneralSettings) {
        let file = StoredFile(version: Self.version, isPaused: settings.isPaused, excludedBundleIDs: settings.excludedBundleIDs)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(file) else { return }
        defaults.set(data, forKey: Self.key)
    }
}

private struct StoredFile: Codable {
    let version: Int
    let isPaused: Bool
    let excludedBundleIDs: [String]
}
