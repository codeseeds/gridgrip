import Carbon
import WindowCore

/// Carbon `RegisterEventHotKey` 기반 전역 단축키 등록기.
/// 이벤트 핸들러는 application event target에 첫 `register` 때 1회만 설치하고, 누름(`kEventHotKeyPressed`)만 구독한다.
/// 핸들러는 메인 런루프에서 불리므로 그대로 `onHotKey`를 호출한다.
final class CarbonHotKeyRegistrar: HotKeyRegistering {
    /// 이 앱의 핫키 시그니처 `'WMPh'`.
    static let signature: OSType = 0x574D_5068

    private enum HandlerState {
        case notInstalled
        case installed(EventHandlerRef)
        case failed
    }

    var onHotKey: ((UInt32) -> Void)?
    private var handlerState = HandlerState.notInstalled
    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]

    deinit {
        unregisterAll()
        if case let .installed(handler) = handlerState {
            RemoveEventHandler(handler)
        }
    }

    func register(_ combo: KeyCombo, id: UInt32) -> Bool {
        guard installHandlerIfNeeded() else { return false }
        unregister(id: id)

        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: id)
        let status = RegisterEventHotKey(combo.keyCode, combo.carbonModifierFlags, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else { return false }
        hotKeyRefs[id] = ref
        return true
    }

    func unregister(id: UInt32) {
        guard let ref = hotKeyRefs.removeValue(forKey: id) else { return }
        UnregisterEventHotKey(ref)
    }

    func unregisterAll() {
        for ref in hotKeyRefs.values {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
    }

    /// 설치에 한 번 실패하면 다시 시도하지 않고 이후 모든 등록을 실패로 돌려준다.
    private func installHandlerIfNeeded() -> Bool {
        switch handlerState {
        case .installed: return true
        case .failed: return false
        case .notInstalled: break
        }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        var handler: EventHandlerRef?
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            carbonHotKeyHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handler
        )
        guard status == noErr, let handler else {
            handlerState = .failed
            return false
        }
        handlerState = .installed(handler)
        return true
    }

    fileprivate func handle(_ event: EventRef) -> OSStatus {
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )
        guard status == noErr, hotKeyID.signature == Self.signature else {
            return OSStatus(eventNotHandledErr)
        }
        onHotKey?(hotKeyID.id)
        return noErr
    }
}

/// C 함수 포인터로 넘기는 Carbon 이벤트 핸들러. userData는 등록기(비소유 참조 — 등록기 `deinit`에서 핸들러를 제거한다).
private func carbonHotKeyHandler(_ callRef: EventHandlerCallRef?, _ event: EventRef?, _ userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }
    let registrar = Unmanaged<CarbonHotKeyRegistrar>.fromOpaque(userData).takeUnretainedValue()
    return registrar.handle(event)
}
