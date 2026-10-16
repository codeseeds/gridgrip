import CoreGraphics
import os
import WindowCore

/// 단축키·메뉴 → 포커스된 창 배치. 메인 스레드에서 동기 실행한다(AX 대기 한도 0.25초가 상한).
/// 일시정지는 디스패처 `shouldDispatch`가 이미 거르고, 제외 앱은 여기서 포커스 창 소유 앱 기준으로 막는다.
@MainActor
final class PlacementController {
    private let dispatcher: ActionDispatcher
    private let activation: ActivationPolicy
    private let windowChanges: WindowChangeHub
    /// 사이클 상태를 앱 생애 동안 보존한다.
    private let engine = PlacementEngine<AXWindowElement>()
    private let logger = Logger(subsystem: AppIdentity.bundleIdentifier, category: "placement")

    init(dispatcher: ActionDispatcher, activation: ActivationPolicy, windowChanges: WindowChangeHub) {
        self.dispatcher = dispatcher
        self.activation = activation
        self.windowChanges = windowChanges
    }

    /// 12종만 등록한다. `undo`/`redo`는 되돌리기 기능이 등록한다.
    func registerHandlers() {
        dispatcher.setHandler(for: PlacementCommand.handledActions) { [weak self] action in
            MainActor.assumeIsolated { self?.handle(action) }
        }
    }

    private func handle(_ action: WindowAction) {
        guard let command = PlacementCommand(action: action) else { return }
        let name = action.rawValue
        guard let window = AXWindowElement.focusedWindow() else {
            logger.notice("\(name, privacy: .public): no focused window (no window, no permission, or AX error)")
            return
        }
        if activation.isExcluded(bundleIdentifier: window.bundleIdentifier) {
            logger.info("\(name, privacy: .public): excluded app \(window.bundleIdentifier ?? "-", privacy: .private)")
            return
        }

        switch engine.perform(command, on: window, screens: ScreenProvider.current()) {
        case let .applied(before, after):
            logger.debug("\(name, privacy: .public): applied before=\(String(describing: before), privacy: .public) after=\(String(describing: after), privacy: .public)")
            windowChanges.record(window, before: before, after: after, source: .keyboard)
        case .noChange:
            logger.debug("\(name, privacy: .public): no change")
        case .failed(let failure):
            logger.notice("\(name, privacy: .public): failed \(String(describing: failure), privacy: .public)")
        }
    }
}
