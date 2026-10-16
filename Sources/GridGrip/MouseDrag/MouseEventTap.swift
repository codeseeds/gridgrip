import CoreGraphics
import os
import WindowCore

/// 마우스 조작용 이벤트 탭 (HID 위치, head insert, 능동 탭). 마스크는 `MouseDragEventMask.value`만 쓴다.
/// 콜백은 메인 런루프에서 돈다. flagsChanged는 어떤 경우에도 원래 이벤트를 그대로 돌려준다.
final class MouseEventTap {
    /// mouseMoved·flagsChanged 처리기. true를 돌려주면 이벤트를 삼킨다(flagsChanged는 반환값과 무관하게 전달).
    var handler: ((CGEventType, CGEvent) -> Bool)?

    private let logger = Logger(subsystem: AppIdentity.bundleIdentifier, category: "mouse")
    private var port: CFMachPort?
    private var source: CFRunLoopSource?

    var isRunning: Bool { port != nil }

    /// 콜백은 이 객체를 강한 참조 없이 들고 있으므로, 해제 전에 반드시 탭을 끈다.
    deinit {
        stop()
    }

    /// 이미 켜져 있으면 아무것도 하지 않는다(탭은 항상 1개). 생성 실패 시 throw — 재시도는 기능 등록부 몫.
    func start() throws {
        guard port == nil else { return }
        guard let port = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(MouseDragEventMask.value),
            callback: { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let tap = Unmanaged<MouseEventTap>.fromOpaque(userInfo).takeUnretainedValue()
                return tap.dispatch(type, event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            throw MouseDragError.tapCreationFailed
        }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        self.port = port
        self.source = source
    }

    func stop() {
        guard let port else { return }
        CGEvent.tapEnable(tap: port, enable: false)
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        CFMachPortInvalidate(port)
        self.port = nil
        self.source = nil
    }

    private func dispatch(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let port {
                CGEvent.tapEnable(tap: port, enable: true)
                logger.info("이벤트 탭 재활성화")
            }
            return Unmanaged.passUnretained(event)
        case .flagsChanged:
            _ = handler?(type, event)
            return Unmanaged.passUnretained(event)
        case .mouseMoved:
            return handler?(type, event) == true ? nil : Unmanaged.passUnretained(event)
        default:
            return Unmanaged.passUnretained(event)
        }
    }
}
