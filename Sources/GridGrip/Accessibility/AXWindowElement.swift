import AppKit
import ApplicationServices
import WindowCore

/// 메시징 타임아웃이 걸린 시스템 전역 AX 요소.
enum AXSystem {
    /// 창 요소·앱 요소·시스템 전역 요소 공통 대기 한도(초).
    static let messagingTimeout: Float = 0.25

    static var systemWide: AXUIElement {
        let element = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(element, messagingTimeout)
        return element
    }
}

/// 커서 아래 창 찾기 결과. `window(at:)`의 "없음"을 "응답 없음"과 구분하기 위한 내부 도우미.
enum AXWindowLookup {
    case found(AXWindowElement)
    case noWindow
    case failed(WindowOpError)
}

/// 다른 앱의 창 1개. 공개 AX API로만 조작한다.
/// 창 동일성 = pid 일치 + `CFEqual(element)`. AXError → `WindowOpError` 변환은 이 파일에서만 한다.
final class AXWindowElement: FrameWritable, Hashable {
    let element: AXUIElement
    let pid: pid_t

    /// `AXUIElementGetPid` 실패 시 nil. 생성 시 메시징 타임아웃 0.25초를 건다.
    init?(element: AXUIElement) {
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success else { return nil }
        AXUIElementSetMessagingTimeout(element, AXSystem.messagingTimeout)
        self.element = element
        self.pid = pid
    }

    /// 시스템 전역 요소 → 위치의 요소 → AXWindow 역할이면 그것, 아니면 AXWindow 속성.
    static func window(at point: CGPoint) -> AXWindowElement? {
        if case .found(let window) = lookup(at: point) { return window }
        return nil
    }

    /// `window(at:)`와 같은 순서로 찾되, 응답 없는 앱(`timedOut`)을 "창 없음"과 구분해 돌려준다.
    static func lookup(at point: CGPoint) -> AXWindowLookup {
        var hit: AXUIElement?
        let hitError = AXUIElementCopyElementAtPosition(AXSystem.systemWide, Float(point.x), Float(point.y), &hit)
        guard hitError == .success, let hit else { return lookupFailure(hitError) }
        AXUIElementSetMessagingTimeout(hit, AXSystem.messagingTimeout)

        var role: CFTypeRef?
        let roleError = AXUIElementCopyAttributeValue(hit, kAXRoleAttribute as CFString, &role)
        if roleError == .cannotComplete { return .failed(.timedOut) }

        let candidate: AXUIElement
        if roleError == .success, (role as? String) == (kAXWindowRole as String) {
            candidate = hit
        } else {
            var windowValue: CFTypeRef?
            let windowError = AXUIElementCopyAttributeValue(hit, kAXWindowAttribute as CFString, &windowValue)
            guard windowError == .success, let windowValue, CFGetTypeID(windowValue) == AXUIElementGetTypeID() else {
                return lookupFailure(windowError)
            }
            candidate = windowValue as! AXUIElement
        }

        guard let window = AXWindowElement(element: candidate) else { return .noWindow }
        return .found(window)
    }

    /// 찾기 단계에서는 응답 없음만 따로 구분하고, 나머지는 "창 없음"(바탕화면·메뉴바 등)으로 본다.
    private static func lookupFailure(_ error: AXError) -> AXWindowLookup {
        error == .cannotComplete ? .failed(.timedOut) : .noWindow
    }

    var bundleIdentifier: String? {
        NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
    }

    /// 앱 요소의 AXFrontmost = true.
    func bringAppToFront() {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, AXSystem.messagingTimeout)
        AXUIElementSetAttributeValue(app, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
    }

    // MARK: - FrameWritable

    func readFrame() -> Result<CGRect, WindowOpError> {
        let origin: AXValue
        let size: AXValue
        switch copyValue(kAXPositionAttribute) {
        case .success(let value): origin = value
        case .failure(let error): return .failure(error)
        }
        switch copyValue(kAXSizeAttribute) {
        case .success(let value): size = value
        case .failure(let error): return .failure(error)
        }
        var point = CGPoint.zero
        var extent = CGSize.zero
        guard AXValueGetValue(origin, .cgPoint, &point), AXValueGetValue(size, .cgSize, &extent) else {
            return .failure(.failed(code: AXError.illegalArgument.rawValue))
        }
        return .success(CGRect(origin: point, size: extent))
    }

    func setPosition(_ p: CGPoint) -> Result<Void, WindowOpError> {
        var point = p
        return setValue(kAXPositionAttribute, AXValueCreate(.cgPoint, &point))
    }

    func setSize(_ s: CGSize) -> Result<Void, WindowOpError> {
        var size = s
        return setValue(kAXSizeAttribute, AXValueCreate(.cgSize, &size))
    }

    // MARK: - Hashable

    static func == (lhs: AXWindowElement, rhs: AXWindowElement) -> Bool {
        lhs.pid == rhs.pid && CFEqual(lhs.element, rhs.element)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(pid)
        hasher.combine(CFHash(element))
    }

    // MARK: - AX 값 읽기·쓰기

    private func copyValue(_ attribute: String) -> Result<AXValue, WindowOpError> {
        var raw: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &raw)
        guard error == .success else { return .failure(mapError(error)) }
        guard let raw, CFGetTypeID(raw) == AXValueGetTypeID() else {
            return .failure(.failed(code: AXError.illegalArgument.rawValue))
        }
        return .success(raw as! AXValue)
    }

    private func setValue(_ attribute: String, _ value: AXValue?) -> Result<Void, WindowOpError> {
        guard let value else { return .failure(.failed(code: AXError.illegalArgument.rawValue)) }
        let error = AXUIElementSetAttributeValue(element, attribute as CFString, value)
        return error == .success ? .success(()) : .failure(mapError(error))
    }

    /// AXError → WindowOpError. 응답 없음이라도 소유 프로세스가 끝났으면 창 사라짐으로 본다.
    private func mapError(_ error: AXError) -> WindowOpError {
        switch error {
        case .invalidUIElement:
            return .windowGone
        case .cannotComplete:
            return isProcessGone ? .windowGone : .timedOut
        case .attributeUnsupported, .notImplemented:
            return .notSettable
        default:
            return .failed(code: error.rawValue)
        }
    }

    private var isProcessGone: Bool {
        kill(pid, 0) != 0 && errno == ESRCH
    }
}
