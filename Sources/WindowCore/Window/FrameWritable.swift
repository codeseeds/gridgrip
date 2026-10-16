import CoreGraphics

/// 창 1개를 읽고 쓰는 최소 추상. 실행 타깃의 `AXWindowElement`가 구현하고, 테스트는 가짜 구현을 쓴다.
public protocol FrameWritable: AnyObject {
    func readFrame() -> Result<CGRect, WindowOpError>
    func setPosition(_ p: CGPoint) -> Result<Void, WindowOpError>
    func setSize(_ s: CGSize) -> Result<Void, WindowOpError>
}
