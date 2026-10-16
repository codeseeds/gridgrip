import AppKit
import os
import WindowCore

/// 시작 순서: AppContext → 기능 등록 → 메뉴 → 권한 점검 1회(apply) → 주기 점검 → 안내 대화상자.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: AppIdentity.bundleIdentifier, category: "app")
    private let accessibility = AccessibilityPermission()
    private let registry = FeatureRegistry()
    private var context: AppContext?
    private var statusItemController: StatusItemController?
    private var permissionMonitor: PermissionMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        logger.info("시작 \(AppIdentity.version, privacy: .public)")

        let coordinator = AppPermissionCoordinator(registry: registry)
        let launchState: PermissionState = accessibility.isTrusted(prompt: false) ? .granted : .denied
        let ctx = AppContext(defaults: .standard, permission: { coordinator.state ?? launchState })
        context = ctx

        registry.onStartFailure = { [logger] featureID, error in
            logger.error("기능 시작 실패: \(featureID, privacy: .public) — \(String(describing: error))")
        }
        for feature in AppAssembly.makeFeatures(ctx) {
            do {
                try registry.register(feature)
            } catch {
                logger.error("기능 등록 실패: \(feature.featureID, privacy: .public) — \(String(describing: error))")
            }
        }

        let accessibility = self.accessibility
        let controller = StatusItemController(
            contributors: AppAssembly.makeMenuContributors(ctx),
            permission: ctx.permission,
            openSystemSettings: { accessibility.openSystemSettings() }
        )
        statusItemController = controller
        ctx.menuRebuildHandler = { [weak controller] in controller?.rebuildMenu() }

        // (R2) 등록 직후 1회 — 이후 등록은 닫힌다.
        let firstCheck = coordinator.check(trusted: accessibility.isTrusted(prompt: false))
        logger.info("시작 시 권한 상태: \(firstCheck.state == .granted ? "허용" : "미허용", privacy: .public)")
        controller.rebuildMenu()

        let monitor = PermissionMonitor(coordinator: coordinator, permission: accessibility) { [weak controller] _ in
            controller?.rebuildMenu()
        }
        permissionMonitor = monitor
        monitor.start(initialInterval: firstCheck.nextInterval)

        // 실행 완료 뒤에 대화상자를 순차로 띄운다.
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated {
                self?.presentStartupNotices(initialState: firstCheck.state)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissionMonitor?.stop()
        registry.stopAll()
        logger.info("종료")
    }

    private func presentStartupNotices(initialState: PermissionState) {
        if initialState == .denied, Alerts.showPermissionAlert() {
            accessibility.openSystemSettings()
        }
        presentConflictNoticeIfFirstLaunch()
    }

    private func presentConflictNoticeIfFirstLaunch() {
        guard let defaults = context?.defaults else { return }
        let alreadyChecked = defaults.bool(forKey: AppStateKeys.didRunFirstLaunchCheck)
        guard !alreadyChecked else { return }
        let running = NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier)
        let conflicts = ConflictNoticePolicy.conflicts(runningBundleIDs: running)
        if ConflictNoticePolicy.shouldShowNotice(conflicts: conflicts, alreadyChecked: alreadyChecked) {
            Alerts.showConflictNotice(conflicts)
        }
        defaults.set(true, forKey: AppStateKeys.didRunFirstLaunchCheck)
    }
}
