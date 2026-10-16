import Foundation
import os
import WindowCore

/// 단축키 기능의 공유 객체 접근자. 엔진·디스패처는 이 접근자로만 받는다(두 번째 인스턴스 금지).
extension AppContext {
    var actionDispatcher: ActionDispatcher {
        shared { ActionDispatcher() }
    }

    var shortcutEngine: ShortcutEngine {
        shared {
            ShortcutEngine(store: ShortcutStore(defaults: defaults),
                           registrar: CarbonHotKeyRegistrar(),
                           dispatcher: actionDispatcher)
        }
    }
}

extension AppAssembly {
    /// 조립 시점(첫 `apply` 전)에 실행된다. 여기서는 아무 단축키도 등록하지 않는다.
    static func installShortcuts(_ ctx: AppContext) -> [AppFeature] {
        let logger = Logger(subsystem: AppIdentity.bundleIdentifier, category: "hotkey")

        // ctx를 잡지 않는다(ctx가 디스패처를 보관하므로 순환 참조 방지).
        ctx.actionDispatcher.shouldDispatch = { [activation = ctx.activation] _ in !activation.isPaused }

        let engine = ctx.shortcutEngine
        engine.onEvent = { event in
            switch event {
            case let .hotKeyFired(action, handled):
                logger.info("hotkey fired: \(action.rawValue, privacy: .public) handled=\(handled, privacy: .public)")
            case let .registrationFailed(action, combo):
                logger.error("hotkey register failed: \(action.rawValue, privacy: .public) \(combo.displayString, privacy: .public)")
            }
        }
        for issue in engine.loadIssues {
            logger.notice("shortcut store recovered: \(describe(issue), privacy: .public)")
        }

        return [ShortcutsFeature(engine: engine)]
    }

    private static func describe(_ issue: ShortcutLoadIssue) -> String {
        switch issue {
        case .corruptData: return "corruptData"
        case let .invalidModifiers(action): return "invalidModifiers(\(action.rawValue))"
        case let .duplicateCleared(action): return "duplicateCleared(\(action.rawValue))"
        }
    }
}
