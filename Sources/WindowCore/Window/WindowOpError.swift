import Foundation

/// 창 1개를 읽고 쓸 때의 실패 사유. AXError 변환은 실행 타깃 `AXWindowElement` 한 곳에서만 한다.
public enum WindowOpError: Error, Equatable {
    /// kAXErrorInvalidUIElement, 또는 소유 프로세스 종료
    case windowGone
    /// kAXErrorCannotComplete (응답 없는 앱, 0.25초 초과)
    case timedOut
    /// 속성 쓰기 불가(크기 고정 창 등)
    case notSettable
    /// 그 밖의 AXError 원값
    case failed(code: Int32)
}
