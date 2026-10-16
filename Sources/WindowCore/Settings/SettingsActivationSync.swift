import Foundation

/// 저장값 ↔ `ActivationPolicy` ↔ 단축키 엔진 사유(`.userPaused`·`.excludedAppFrontmost`) 동기화.
/// `.recording` 사유는 녹화 칸만 소유하므로 여기서 건드리지 않는다. 메인 스레드에서만 사용한다.
public enum SettingsActivationSync {
    /// 시작 시 저장값을 `ActivationPolicy`에 반영한다.
    public static func load(_ store: GeneralSettingsStore, into policy: ActivationPolicy) {
        let settings = store.load()
        policy.update(isPaused: settings.isPaused, excludedBundleIDs: settings.excludedBundleIDs)
    }

    /// 멱등: 같은 상태로 다시 불러도 엔진 사유 집합이 바뀌지 않으므로 등록 변화가 없다.
    public static func syncSuspendReasons(engine: ShortcutEngine, policy: ActivationPolicy, frontmostBundleID: String?) {
        if policy.isPaused {
            engine.suspend(.userPaused)
        } else {
            engine.resume(.userPaused)
        }
        if policy.isExcluded(bundleIdentifier: frontmostBundleID) {
            engine.suspend(.excludedAppFrontmost)
        } else {
            engine.resume(.excludedAppFrontmost)
        }
    }

    /// 값이 바뀔 때마다 `general.v1` 저장 → 엔진 사유 재동기화 → `onChange`(화면 갱신 등) 순으로 실행하도록 관찰자를 건다.
    public static func connect(policy: ActivationPolicy,
                               store: GeneralSettingsStore,
                               engine: ShortcutEngine,
                               frontmostBundleID: @escaping () -> String?,
                               onChange: @escaping () -> Void) {
        policy.addObserver { [weak policy, weak engine] in
            guard let policy, let engine else { return }
            store.save(GeneralSettings(policy: policy))
            syncSuspendReasons(engine: engine, policy: policy, frontmostBundleID: frontmostBundleID())
            onChange()
        }
    }
}
