import Foundation
import WindowCore

/// 후속 기능에 전달하는 공용 의존성 묶음 (시그니처 변경 금지).
/// 각 기능은 자기 파일의 `extension AppContext`에 `shared { ... }` 접근자를 추가한다.
@MainActor
final class AppContext {
    let defaults: UserDefaults
    /// 가장 최근 권한 점검 결과. AX를 직접 부르지 않는다.
    let permission: () -> PermissionState
    let activation: ActivationPolicy

    /// `requestMenuRebuild()`의 전달 대상. AppDelegate만 설정한다(메뉴 컨트롤러 생성 전에는 nil).
    var menuRebuildHandler: (() -> Void)?
    private let sharedStore = AppSharedStore()

    init(defaults: UserDefaults = .standard, permission: @escaping () -> PermissionState, activation: ActivationPolicy = ActivationPolicy()) {
        self.defaults = defaults
        self.permission = permission
        self.activation = activation
    }

    func requestMenuRebuild() {
        menuRebuildHandler?()
    }

    /// 타입별 1개만 지연 생성해 보관한다. 같은 타입을 두 번 요청하면 같은 인스턴스를 돌려준다.
    /// make 안에서 다른 shared 접근자를 불러도 된다. 순환 생성은 preconditionFailure.
    func shared<T: AnyObject>(_ type: T.Type = T.self, make: () -> T) -> T {
        do {
            return try sharedStore.resolve(type, make: make)
        } catch AppSharedStoreError.cycle(let typeName) {
            preconditionFailure("AppContext.shared 순환 생성: \(typeName)")
        } catch {
            preconditionFailure("AppContext.shared 실패: \(error)")
        }
    }
}

@MainActor
enum AppAssembly {
    static func makeFeatures(_ ctx: AppContext) -> [AppFeature] {
        var features: [AppFeature] = []

        features += installShortcuts(ctx)

        features += installMouseDrag(ctx)

        features += installPlacement(ctx)

        features += installSettings(ctx)

        features += installUndo(ctx)

        return features
    }

    static func makeMenuContributors(_ ctx: AppContext) -> [MenuContributor] {
        var contributors: [MenuContributor] = []

        contributors += settingsMenuContributors(ctx)

        return contributors
    }
}
