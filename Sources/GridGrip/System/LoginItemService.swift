import Foundation
import ServiceManagement
import WindowCore

/// 로그인 시 실행 = `SMAppService.mainApp` 래퍼. 상태는 저장하지 않고 매번 시스템에서 읽는다.
/// deprecated `LSSharedFileList`·로그인 헬퍼 앱 방식은 쓰지 않는다.
struct LoginItemService {
    /// 번들(.app) 밖 실행(`swift run`)이면 `.notFound` — 실행 파일 자체를 로그인 항목으로 등록하지 않는다.
    var status: LoginItemStatus {
        guard isBundledApp else { return .notFound }
        return LoginItemStatus.resolve(isBundledApp: true, serviceStatus: serviceStatus)
    }

    private var serviceStatus: LoginItemStatus {
        switch SMAppService.mainApp.status {
        case .enabled: return .enabled
        case .notRegistered: return .notRegistered
        case .requiresApproval: return .requiresApproval
        case .notFound: return .notFound
        @unknown default: return .notFound
        }
    }

    /// 실패해도 throw하지 않고 실제 상태를 다시 읽어 오류 설명과 함께 돌려준다.
    func setEnabled(_ on: Bool) -> (status: LoginItemStatus, errorDescription: String?) {
        guard isBundledApp else { return (.notFound, nil) }
        do {
            if on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return (status, nil)
        } catch {
            return (status, error.localizedDescription)
        }
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    private var isBundledApp: Bool {
        Bundle.main.bundleIdentifier != nil && Bundle.main.bundleURL.pathExtension == "app"
    }
}
