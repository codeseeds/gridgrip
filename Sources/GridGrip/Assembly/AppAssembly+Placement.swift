import WindowCore

extension AppContext {
    var placementController: PlacementController {
        shared {
            PlacementController(dispatcher: actionDispatcher, activation: activation, windowChanges: windowChanges)
        }
    }
}

extension AppAssembly {
    /// 배치 핸들러 12종 등록. 시작/정지할 자원이 없으므로 `AppFeature`는 돌려주지 않는다.
    static func installPlacement(_ ctx: AppContext) -> [AppFeature] {
        ctx.placementController.registerHandlers()
        return []
    }
}
