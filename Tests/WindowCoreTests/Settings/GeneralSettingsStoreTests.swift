import XCTest
import WindowCore

final class GeneralSettingsStoreTests: XCTestCase {
    private var suite: SettingsTestDefaults!

    override func setUp() {
        super.setUp()
        suite = SettingsTestDefaults()
    }

    override func tearDown() {
        suite.tearDown()
        suite = nil
        super.tearDown()
    }

    func testRoundTrip() throws {
        let saved = GeneralSettings(isPaused: true, excludedBundleIDs: ["com.apple.dt.Xcode", "com.apple.Safari"])
        GeneralSettingsStore(defaults: suite.defaults).save(saved)

        let loaded = GeneralSettingsStore(defaults: suite.defaults).load()
        XCTAssertEqual(loaded, saved)

        let data = try XCTUnwrap(suite.defaults.data(forKey: GeneralSettingsStore.key))
        XCTAssertEqual(GeneralSettingsStore.key, "general.v1")
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["version"] as? Int, 1)
        XCTAssertEqual(json["isPaused"] as? Bool, true)
        XCTAssertEqual(json["excludedBundleIDs"] as? [String], ["com.apple.dt.Xcode", "com.apple.Safari"])
    }

    func testDefaultsWhenEmpty() {
        let store = GeneralSettingsStore(defaults: suite.defaults)
        let loaded = store.load()
        XCTAssertFalse(loaded.isPaused)
        XCTAssertEqual(loaded.excludedBundleIDs, [])
        XCTAssertFalse(store.lastLoadRecovered)
    }

    func testCorruptedData() {
        let store = GeneralSettingsStore(defaults: suite.defaults)
        let corrupted: [Any] = [
            "not json",
            42,
            Data(#"{"version":1,"isPaused":"yes","excludedBundleIDs":3}"#.utf8),
        ]
        for value in corrupted {
            suite.defaults.set(value, forKey: GeneralSettingsStore.key)
            let loaded = store.load()
            XCTAssertEqual(loaded, GeneralSettings(), "\(value)")
            XCTAssertTrue(store.lastLoadRecovered, "\(value)")
        }
    }

    // 보강: 버전이 다르면 손상으로 본다.
    func testUnknownVersionIsCorrupt() {
        suite.defaults.set(Data(#"{"version":2,"isPaused":true,"excludedBundleIDs":[]}"#.utf8), forKey: GeneralSettingsStore.key)
        let store = GeneralSettingsStore(defaults: suite.defaults)
        XCTAssertEqual(store.load(), GeneralSettings())
        XCTAssertTrue(store.lastLoadRecovered)
    }

    func testSanitizeOnLoad() {
        let data = Data(#"{"version":1,"isPaused":false,"excludedBundleIDs":["com.a","","com.b","COM.A"]}"#.utf8)
        suite.defaults.set(data, forKey: GeneralSettingsStore.key)
        let loaded = GeneralSettingsStore(defaults: suite.defaults).load()
        XCTAssertEqual(loaded.excludedBundleIDs, ["com.a", "com.b"])
    }

    // 저장값에 들어간 우리 앱 자신의 번들 ID는 로드 시 제거
    func testSelfBundleIDRemovedOnLoad() {
        let data = Data(#"{"version":1,"isPaused":false,"excludedBundleIDs":["com.a","COM.BLACKPET.GRIDGRIP"]}"#.utf8)
        suite.defaults.set(data, forKey: GeneralSettingsStore.key)
        XCTAssertEqual(GeneralSettingsStore(defaults: suite.defaults).load().excludedBundleIDs, ["com.a"])
    }

    // 로드 시 항목 길이 상한 255자·개수 상한 500개
    func testLimitsOnLoad() throws {
        let tooLong = String(repeating: "a", count: GeneralSettings.maxBundleIDLength + 1)
        let maxLength = String(repeating: "b", count: GeneralSettings.maxBundleIDLength)
        let many = (0..<(GeneralSettings.maxExcludedCount + 20)).map { "com.app\($0)" }
        let ids = [tooLong, maxLength] + many
        let data = try JSONSerialization.data(withJSONObject: ["version": 1, "isPaused": false, "excludedBundleIDs": ids])
        suite.defaults.set(data, forKey: GeneralSettingsStore.key)

        let loaded = GeneralSettingsStore(defaults: suite.defaults).load().excludedBundleIDs
        XCTAssertEqual(GeneralSettings.maxExcludedCount, 500)
        XCTAssertEqual(GeneralSettings.maxBundleIDLength, 255)
        XCTAssertEqual(loaded.count, 500)
        XCTAssertEqual(loaded.first, maxLength)
        XCTAssertFalse(loaded.contains(tooLong))
        XCTAssertEqual(loaded.last, "com.app498")
    }
}
