import AppKit
import WindowCore

/// 맨 앞 앱 감시 → 단축키 엔진 사유(`.userPaused`·`.excludedAppFrontmost`) 동기화 (featureID "activation", 권한 불필요).
/// 기능 등록부가 메인 스레드에서 start/stop을 부른다. 권한 점검·`AXIsProcessTrusted*`는 부르지 않는다.
final class ActivationController: AppFeature {
    let featureID = "activation"
    let requiresAccessibility = false
    private let engine: ShortcutEngine
    private let policy: ActivationPolicy
    private var observer: NSObjectProtocol?

    init(engine: ShortcutEngine, policy: ActivationPolicy) {
        self.engine = engine
        self.policy = policy
    }

    func start() throws {
        guard observer == nil else { return }
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            self?.sync(frontmostBundleID: app?.bundleIdentifier)
        }
        // 조립 시점 확인 이후 시작 전까지 맨 앞 앱이 바뀌었을 수 있다.
        reevaluate()
    }

    func stop() {
        if let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        observer = nil
    }

    /// 현재 맨 앞 앱 기준으로 다시 판정한다.
    func reevaluate() {
        sync(frontmostBundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier)
    }

    private func sync(frontmostBundleID: String?) {
        SettingsActivationSync.syncSuspendReasons(engine: engine, policy: policy, frontmostBundleID: frontmostBundleID)
    }
}
