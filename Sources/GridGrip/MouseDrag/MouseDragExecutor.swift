import Foundation
import WindowCore

/// 최신 1건 실행기 + 끝난 조작 보관함. 순서 로직은 WindowCore `MouseDragWriteQueue`(XCTest로 검증)에 있다.
typealias MouseDragExecutor = MouseDragWriteQueue<AXWindowElement>

extension MouseDragWriteQueue where Window == AXWindowElement {
    /// 전용 직렬 큐 `com.blackpet.GridGrip.mousedrag`에서 쓰고, 결과는 메인으로 비동기 전달한다.
    static func makeForApp() -> MouseDragExecutor {
        MouseDragExecutor(
            queue: DispatchQueue(label: AppIdentity.bundleIdentifier + ".mousedrag", qos: .userInteractive),
            deliver: { DispatchQueue.main.async(execute: $0) }
        )
    }
}
