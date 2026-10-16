import CoreGraphics

/// "같은 프레임" 판정의 단일 기준. 기록·쓰기 결과 판정이 모두 이 값을 쓴다.
public enum FrameTolerance {
    public static let points: CGFloat = 2

    /// x·y·w·h 각각 |차| ≤ tolerance
    public static func isSame(_ a: CGRect, _ b: CGRect, tolerance: CGFloat = points) -> Bool {
        abs(a.origin.x - b.origin.x) <= tolerance
            && abs(a.origin.y - b.origin.y) <= tolerance
            && abs(a.size.width - b.size.width) <= tolerance
            && abs(a.size.height - b.size.height) <= tolerance
    }
}
