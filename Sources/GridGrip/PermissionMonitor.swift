import Foundation
import os
import WindowCore

/// 손쉬운 사용 권한 주기 점검. 매 점검마다 `coordinator.check`를 불러 기능 시작/정지·재시도를 맡긴다.
/// 전환이 있을 때만 로그 1줄과 `onTransition`(메뉴 재구성)을 실행한다.
@MainActor
final class PermissionMonitor {
    private let coordinator: AppPermissionCoordinator
    private let permission: AccessibilityPermission
    private let onTransition: (AppPermissionCheck) -> Void
    private let logger = Logger(subsystem: AppIdentity.bundleIdentifier, category: "permission")
    private var timer: Timer?
    private var isRunning = false

    init(coordinator: AppPermissionCoordinator, permission: AccessibilityPermission, onTransition: @escaping (AppPermissionCheck) -> Void) {
        self.coordinator = coordinator
        self.permission = permission
        self.onTransition = onTransition
    }

    func start(initialInterval: TimeInterval) {
        isRunning = true
        schedule(after: initialInterval)
    }

    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    /// 반복 없는 타이머를 매번 다시 예약한다. `.common` 모드로 등록해
    /// 대화상자(NSAlert)나 메뉴가 열려 있는 동안에도 점검이 멈추지 않게 한다.
    private func schedule(after interval: TimeInterval) {
        timer?.invalidate()
        let next = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tick()
            }
        }
        RunLoop.main.add(next, forMode: .common)
        timer = next
    }

    private func tick() {
        guard isRunning else { return }
        let result = coordinator.check(trusted: permission.isTrusted(prompt: false))
        if let transition = result.transition {
            switch transition {
            case .becameGranted: logger.info("권한 허용됨")
            case .becameRevoked: logger.info("권한 철회됨")
            }
            onTransition(result)
        }
        guard isRunning else { return }
        schedule(after: result.nextInterval)
    }
}
