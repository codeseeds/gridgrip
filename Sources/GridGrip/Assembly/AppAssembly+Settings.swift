import AppKit
import os
import WindowCore

/// 설정 기능의 공유 객체 접근자. 다른 기능 소유 객체는 `ctx.shortcutEngine`·`ctx.actionDispatcher`·`ctx.activation`으로만 받는다.
extension AppContext {
    var generalSettingsStore: GeneralSettingsStore {
        shared { GeneralSettingsStore(defaults: defaults) }
    }

    var historyMenuState: HistoryMenuState {
        shared { HistoryMenuState() }
    }

    /// 만들기만 하고 창은 처음 열 때 생성한다.
    var settingsWindowController: SettingsWindowController {
        shared {
            SettingsWindowController(engine: shortcutEngine, activation: activation, defaults: defaults,
                                     logger: Logger(subsystem: AppIdentity.bundleIdentifier, category: "settings"))
        }
    }
}

extension AppAssembly {
    /// 조립 시점(첫 `apply` = 엔진 `start()` 전)에 실행된다. 순서를 바꾸지 마라.
    static func installSettings(_ ctx: AppContext) -> [AppFeature] {
        let logger = Logger(subsystem: AppIdentity.bundleIdentifier, category: "settings")
        let store = ctx.generalSettingsStore
        let engine = ctx.shortcutEngine
        let activation = ctx.activation

        // ① 저장값 → ActivationPolicy
        SettingsActivationSync.load(store, into: activation)
        if store.lastLoadRecovered {
            logger.notice("general.v1 손상 — 기본값(일시정지 아님·제외 없음)으로 시작")
        }

        // ② 일시정지·맨 앞 제외 앱 → 엔진 사유 (start 전이므로 저장된 일시정지가 시작 순간부터 지켜진다)
        SettingsActivationSync.syncSuspendReasons(engine: engine, policy: activation,
                                                  frontmostBundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier)

        // ③ 값이 바뀌면 저장 + 사유 재동기화 + 설정 창 갱신(창을 연 적 없으면 갱신 생략).
        // ctx를 잡지 않는다(ctx가 정책·엔진을 보관하므로 순환 참조 방지).
        let settingsWindow = ctx.settingsWindowController
        SettingsActivationSync.connect(policy: activation, store: store, engine: engine,
                                       frontmostBundleID: { NSWorkspace.shared.frontmostApplication?.bundleIdentifier },
                                       onChange: { [weak settingsWindow] in
                                           MainActor.assumeIsolated { settingsWindow?.refresh() }
                                       })
        // 단축키 엔진의 단일 클로저를 덮어쓰지 않고 체인으로 잇는다.
        let previousOnChange = engine.onChange
        engine.onChange = { [weak settingsWindow] in
            previousOnChange?()
            MainActor.assumeIsolated { settingsWindow?.refresh() }
        }

        // ④ 맨 앞 앱 감시
        return [ActivationController(engine: engine, policy: activation)]
    }

    static func settingsMenuContributors(_ ctx: AppContext) -> [MenuContributor] {
        [
            ActionMenuContributor(engine: ctx.shortcutEngine, activation: ctx.activation, dispatcher: ctx.actionDispatcher),
            HistoryMenuContributor(engine: ctx.shortcutEngine, activation: ctx.activation,
                                   historyState: ctx.historyMenuState, dispatcher: ctx.actionDispatcher),
            ControlMenuContributor(activation: ctx.activation),
            PreferencesMenuContributor(settingsWindow: ctx.settingsWindowController),
        ]
    }
}
