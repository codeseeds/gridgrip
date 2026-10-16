import WindowCore

extension AppContext {
    var undoController: UndoController {
        shared { UndoController(windowChanges: windowChanges) }
    }
}

extension AppAssembly {
    /// 허브 기록 연결·되돌리기/다시하기 핸들러 등록·메뉴 활성 연결. 시작/정지할 자원이 없으므로 `AppFeature`는 돌려주지 않는다.
    static func installUndo(_ ctx: AppContext) -> [AppFeature] {
        ctx.windowChanges.recorder = ctx.undoController
        ctx.actionDispatcher.setHandler(for: [.undo, .redo]) { [weak controller = ctx.undoController] action in
            MainActor.assumeIsolated {
                if action == .undo { controller?.performUndo() } else { controller?.performRedo() }
            }
        }
        ctx.historyMenuState.canUndo = { [weak u = ctx.undoController] in MainActor.assumeIsolated { u?.canUndo ?? false } }
        ctx.historyMenuState.canRedo = { [weak u = ctx.undoController] in MainActor.assumeIsolated { u?.canRedo ?? false } }
        return []
    }
}
