/// 엔진이 창을 다루는 추상. 읽기·쓰기는 `FrameWritable`의 `readFrame`/`setPosition`/`setSize` 그대로 쓴다.
/// 실행 타깃의 `AXWindowElement`가 extension으로 채택하고, 테스트는 가짜 구현을 쓴다.
public protocol PlaceableWindow: FrameWritable {
    var isResizable: Bool { get }
    var isMinimized: Bool { get }
    var isFullScreen: Bool { get }
}
