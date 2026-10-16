import XCTest
import WindowCore

/// 테스트 공용 가짜 전역 단축키 등록기. 호출을 순서대로 기록하고, 지정한 조합은 실패시킨다.
final class SettingsFakeRegistrar: HotKeyRegistering {
    enum Call: Equatable {
        case register(KeyCombo, id: UInt32)
        case unregister(id: UInt32)
        case unregisterAll
    }

    var onHotKey: ((UInt32) -> Void)?
    var calls: [Call] = []
    var failingCombos: Set<KeyCombo> = []

    var registerCount: Int {
        calls.filter { if case .register = $0 { return true } else { return false } }.count
    }

    var unregisterAllCount: Int {
        calls.filter { $0 == .unregisterAll }.count
    }

    func register(_ combo: KeyCombo, id: UInt32) -> Bool {
        calls.append(.register(combo, id: id))
        return !failingCombos.contains(combo)
    }

    func unregister(id: UInt32) {
        calls.append(.unregister(id: id))
    }

    func unregisterAll() {
        calls.append(.unregisterAll)
    }
}

/// suite 이름에 모듈명 `Settings`를 넣은 격리 UserDefaults.
final class SettingsTestDefaults {
    let suiteName = "Settings-test-\(UUID().uuidString)"
    let defaults: UserDefaults

    init() {
        defaults = UserDefaults(suiteName: suiteName)!
    }

    func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
    }

    /// 실제 `ShortcutEngine` + 가짜 등록기.
    func makeEngine(registrar: SettingsFakeRegistrar) -> ShortcutEngine {
        ShortcutEngine(store: ShortcutStore(defaults: defaults), registrar: registrar, dispatcher: ActionDispatcher())
    }
}
