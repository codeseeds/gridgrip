import WindowCore

enum MouseDragError: Error {
    case tapCreationFailed
}

/// 마우스 이동·크기조정 기능 (featureID "mouseDrag", 권한 필요).
/// 기능 등록부가 메인 스레드에서 start/stop을 부른다(AppDelegate·PermissionMonitor 모두 메인).
final class MouseDragFeature: AppFeature {
    let featureID = "mouseDrag"
    let requiresAccessibility = true
    private let controller: MouseDragController

    init(controller: MouseDragController) {
        self.controller = controller
    }

    /// 탭 생성 실패는 throw로만 알린다. 재시도는 다음 권한 점검 때 기능 등록부가 한다.
    func start() throws {
        try MainActor.assumeIsolated { try controller.start() }
    }

    func stop() {
        MainActor.assumeIsolated { controller.stop() }
    }
}
