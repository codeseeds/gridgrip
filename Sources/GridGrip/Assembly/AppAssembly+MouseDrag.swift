import WindowCore

extension AppContext {
    var mouseDragController: MouseDragController {
        shared {
            MouseDragController(
                activation: activation,
                windowChanges: windowChanges,
                settingsStore: MouseDragSettingsStore(defaults: defaults)
            )
        }
    }

    var windowChanges: WindowChangeHub {
        shared { WindowChangeHub() }
    }
}

extension AppAssembly {
    /// 진행 중 조작 마무리 함수를 허브에 등록하고, 시작/정지가 필요한 마우스 기능 1개를 돌려준다.
    static func installMouseDrag(_ ctx: AppContext) -> [AppFeature] {
        ctx.windowChanges.addPendingOperationFinisher { [weak controller = ctx.mouseDragController] in
            MainActor.assumeIsolated { controller?.finishActiveOperationSynchronously() }
        }
        return [MouseDragFeature(controller: ctx.mouseDragController)]
    }
}
