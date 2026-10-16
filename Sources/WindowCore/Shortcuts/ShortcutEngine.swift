import Foundation

/// 단축키 일시정지 사유. 넣고 빼는 쪽은 설정 기능.
public enum SuspendReason: Hashable {
    case userPaused
    case recording
    case excludedAppFrontmost
}

public enum ShortcutChangeResult: Equatable {
    case applied
    case invalidModifiers
    case conflict([WindowAction])
}

/// 엔진이 실행 타깃에 알리는 진단 사실. 실행 타깃이 로그로 바꾼다.
public enum ShortcutEngineEvent: Equatable {
    case hotKeyFired(WindowAction, handled: Bool)
    case registrationFailed(WindowAction, KeyCombo)
}

/// 단축키 바인딩 보관·변경·검증, 등록기 호출, 핫키 번호 → 동작 디스패치, 사유별 일시정지를 맡는 조정자.
/// 실제 등록은 "활성"(= `isStarted`이고 `suspendReasons`가 비어 있음)일 때만 한다. 메인 스레드에서만 사용한다.
public final class ShortcutEngine {
    public private(set) var bindings: ShortcutBindings
    public private(set) var isStarted = false
    public private(set) var suspendReasons: Set<SuspendReason> = []
    public private(set) var registrationFailures: Set<WindowAction> = []
    /// 생성 시 저장소가 저장값을 복구한 사실(조립부가 로그로 남긴다).
    public let loadIssues: [ShortcutLoadIssue]

    /// `bindings` 또는 `registrationFailures`가 실제로 바뀐 공개 호출마다 1회.
    public var onChange: (() -> Void)?
    public var onEvent: ((ShortcutEngineEvent) -> Void)?

    public var isSuspended: Bool { !suspendReasons.isEmpty }

    private let store: ShortcutStore
    private let registrar: HotKeyRegistering
    private let dispatcher: ActionDispatcher

    private var isActive: Bool { isStarted && suspendReasons.isEmpty }

    public init(store: ShortcutStore, registrar: HotKeyRegistering, dispatcher: ActionDispatcher) {
        self.store = store
        self.registrar = registrar
        self.dispatcher = dispatcher
        self.bindings = store.load()
        self.loadIssues = store.lastLoadIssues
        // 엔진 → 등록기는 강한 참조, 등록기 → 엔진은 약한 참조(순환 참조 없음).
        registrar.onHotKey = { [weak self] id in self?.handleHotKey(id: id) }
    }

    public func shortcut(for action: WindowAction) -> KeyCombo? {
        bindings[action]
    }

    // MARK: - 시작·정지·일시정지

    /// 멱등. 사유가 있으면 시작 표시만 하고 등록하지 않는다. 개별 등록 실패로 throw하지 않는다.
    public func start() {
        guard !isStarted else { return }
        isStarted = true
        if isActive, registerAll() {
            onChange?()
        }
    }

    /// 전체 해제·실패 목록 비움. 사유 집합은 유지한다(다음 `start()`에서도 지킨다).
    public func stop() {
        guard isStarted else { return }
        registrar.unregisterAll()
        isStarted = false
        if clearFailures() {
            onChange?()
        }
    }

    /// 사유 집합이 비어 있음 → 비어 있지 않음이 되는 순간에만 전체 해제.
    public func suspend(_ reason: SuspendReason) {
        let wasActive = isActive
        guard suspendReasons.insert(reason).inserted else { return }
        guard wasActive else { return }
        registrar.unregisterAll()
        if clearFailures() {
            onChange?()
        }
    }

    /// 사유 집합이 비어 있지 않음 → 비어 있음이 되는 순간에만 최신 바인딩으로 전체 재등록.
    public func resume(_ reason: SuspendReason) {
        guard suspendReasons.remove(reason) != nil else { return }
        if isActive, registerAll() {
            onChange?()
        }
    }

    // MARK: - 변경

    /// 규칙 위반 → `.invalidModifiers`, 겹침 → `.conflict`(변경 없음). `replacingConflicts`면 겹친 동작을 지우고 적용.
    /// 저장은 항상 하고, 등록기는 활성일 때만 부른다. 등록 실패여도 저장값은 유지하고 `.applied`.
    @discardableResult
    public func setShortcut(_ combo: KeyCombo?, for action: WindowAction, replacingConflicts: Bool = false) -> ShortcutChangeResult {
        guard combo != bindings[action] else { return .applied }

        var cleared: [WindowAction] = []
        if let combo {
            guard ShortcutValidator.validate(combo) else { return .invalidModifiers }
            let conflicts = ShortcutValidator.conflicts(for: combo, action: action, in: bindings)
            if !conflicts.isEmpty {
                guard replacingConflicts else { return .conflict(conflicts) }
                cleared = conflicts
            }
        }

        var updated = bindings
        for other in cleared {
            updated[other] = nil
        }
        updated[action] = combo
        store.save(updated)
        bindings = updated

        for other in cleared {
            if isActive { registrar.unregister(id: other.hotKeyID) }
            registrationFailures.remove(other)
        }
        if isActive {
            registrar.unregister(id: action.hotKeyID)
            if let combo {
                register(combo, for: action)
            } else {
                registrationFailures.remove(action)
            }
        } else {
            registrationFailures.remove(action)
        }

        onChange?()
        return .applied
    }

    /// 기본값 14종을 명시 저장하고, 활성이면 전체 재등록(이미 기본값이어도 실패했던 등록을 다시 시도).
    public func restoreDefaults() {
        store.restoreDefaults()
        let bindingsChanged = bindings != DefaultShortcuts.bindings
        bindings = DefaultShortcuts.bindings
        let failuresChanged = isActive ? registerAll() : false
        if bindingsChanged || failuresChanged {
            onChange?()
        }
    }

    // MARK: - 전달

    /// 활성이 아니면 무시(늦게 도착한 이벤트 방어). 모르는 번호도 무시.
    public func handleHotKey(id: UInt32) {
        guard isActive, let action = WindowAction(hotKeyID: id) else { return }
        let handled = dispatcher.dispatch(action)
        onEvent?(.hotKeyFired(action, handled: handled))
    }

    // MARK: - 내부

    /// `unregisterAll()` 1회 → nil 아닌 바인딩을 선언 순서대로 등록 → 실패 목록을 새로 계산.
    /// 실패 목록이 바뀌었으면 true.
    private func registerAll() -> Bool {
        let previous = registrationFailures
        registrar.unregisterAll()
        registrationFailures = []
        for action in WindowAction.allCases {
            guard let combo = bindings[action] else { continue }
            register(combo, for: action)
        }
        return registrationFailures != previous
    }

    private func register(_ combo: KeyCombo, for action: WindowAction) {
        if registrar.register(combo, id: action.hotKeyID) {
            registrationFailures.remove(action)
        } else {
            registrationFailures.insert(action)
            onEvent?(.registrationFailed(action, combo))
        }
    }

    /// 실패 목록이 비어 있지 않았으면 비우고 true.
    private func clearFailures() -> Bool {
        guard !registrationFailures.isEmpty else { return false }
        registrationFailures = []
        return true
    }
}
