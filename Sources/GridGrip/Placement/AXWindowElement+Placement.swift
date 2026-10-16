import ApplicationServices
import WindowCore

/// 키보드 배치용 확장. 원본(`AXWindowElement.swift`)은 고치지 않는다.
/// 공개 AX API만 쓴다.
extension AXWindowElement: PlaceableWindow {
    /// 시스템 전역 요소 → 포커스된 앱 요소(대기 한도 0.25초 적용) → 포커스된 창. 어느 단계든 실패하면 nil
    /// (손쉬운 사용 권한이 없으면 첫 단계에서 실패한다).
    static func focusedWindow() -> AXWindowElement? {
        guard let app = placementElement(of: AXSystem.systemWide, kAXFocusedApplicationAttribute) else { return nil }
        AXUIElementSetMessagingTimeout(app, AXSystem.messagingTimeout)
        guard let window = placementElement(of: app, kAXFocusedWindowAttribute) else { return nil }
        return AXWindowElement(element: window)
    }

    /// 크기 속성 쓰기 가능 여부. 조회 실패 시 true(쓰기를 시도해 보고 결과로 판정).
    var isResizable: Bool {
        var settable: DarwinBoolean = false
        guard AXUIElementIsAttributeSettable(element, kAXSizeAttribute as CFString, &settable) == .success else { return true }
        return settable.boolValue
    }

    var isMinimized: Bool {
        placementBool(kAXMinimizedAttribute) ?? false
    }

    /// 네이티브 전체화면. 공개 상수가 없어 속성 이름 문자열을 쓴다.
    var isFullScreen: Bool {
        placementBool("AXFullScreen") ?? false
    }

    private func placementBool(_ attribute: String) -> Bool? {
        var raw: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &raw) == .success,
              let raw, CFGetTypeID(raw) == CFBooleanGetTypeID() else { return nil }
        return CFBooleanGetValue((raw as! CFBoolean))
    }

    private static func placementElement(of parent: AXUIElement, _ attribute: String) -> AXUIElement? {
        var raw: CFTypeRef?
        guard AXUIElementCopyAttributeValue(parent, attribute as CFString, &raw) == .success,
              let raw, CFGetTypeID(raw) == AXUIElementGetTypeID() else { return nil }
        return (raw as! AXUIElement)
    }
}
