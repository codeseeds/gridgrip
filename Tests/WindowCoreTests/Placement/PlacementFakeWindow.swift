import CoreGraphics
import WindowCore

/// 공통 픽스처 (AX 좌표계: 주 모니터 좌상단 원점, y 아래로 증가).
enum PlacementFixtures {
    /// 기준 visibleFrame (maxX 1200, maxY 930)
    static let vf = CGRect(x: 0, y: 30, width: 1200, height: 900)
    static let v = ScreenGeometry(frame: CGRect(x: 0, y: 0, width: 1200, height: 960), visibleFrame: vf)
    /// 주 모니터
    static let a = ScreenGeometry(frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
                                  visibleFrame: CGRect(x: 0, y: 25, width: 1440, height: 875))
    /// 오른쪽 모니터
    static let b = ScreenGeometry(frame: CGRect(x: 1440, y: 0, width: 1920, height: 1080),
                                  visibleFrame: CGRect(x: 1440, y: 0, width: 1920, height: 1080))
    /// 왼쪽 모니터
    static let c = ScreenGeometry(frame: CGRect(x: -1920, y: 320, width: 1920, height: 1080),
                                  visibleFrame: CGRect(x: -1920, y: 320, width: 1920, height: 1080))
}

/// `PlaceableWindow` 가짜 구현. 동일성은 인스턴스 동일(`===`).
/// set 호출 순서·인자 기록, 최소 크기 강제, 쓰기·읽기 실패, N번째 set 호출 이후 창 사라짐을 흉내 낸다.
final class PlacementFakeWindow: PlaceableWindow, Equatable {
    enum Call: Equatable {
        case setSize(CGSize)
        case setPosition(CGPoint)
    }

    private(set) var frame: CGRect
    var minSize: CGSize = .zero
    var isResizable = true
    var isMinimized = false
    var isFullScreen = false

    /// 설정하면 모든 `readFrame()`이 이 오류로 실패한다.
    var readError: WindowOpError?
    /// 설정하면 모든 `setSize`가 이 오류로 실패한다(크기 유지).
    var sizeError: WindowOpError?
    /// 설정하면 모든 `setPosition`이 이 오류로 실패한다(위치 유지).
    var positionError: WindowOpError?
    /// `setPosition` 호출마다 앞에서 1개씩 꺼내 쓴다(nil = 성공). 비면 `positionError`를 따른다.
    var positionResults: [WindowOpError?] = []
    /// set 호출이 이 횟수만큼 끝난 뒤부터 모든 호출(읽기 포함)이 `.windowGone`.
    var goneAfterSetCalls: Int?

    private(set) var calls: [Call] = []

    init(frame: CGRect) {
        self.frame = frame
    }

    static func == (lhs: PlacementFakeWindow, rhs: PlacementFakeWindow) -> Bool { lhs === rhs }

    private var isGone: Bool {
        guard let limit = goneAfterSetCalls else { return false }
        return calls.count >= limit
    }

    func clearCalls() {
        calls.removeAll()
    }

    func readFrame() -> Result<CGRect, WindowOpError> {
        if isGone { return .failure(.windowGone) }
        if let readError { return .failure(readError) }
        return .success(frame)
    }

    func setPosition(_ p: CGPoint) -> Result<Void, WindowOpError> {
        if isGone { return .failure(.windowGone) }
        calls.append(.setPosition(p))
        let error = positionResults.isEmpty ? positionError : positionResults.removeFirst()
        if let error { return .failure(error) }
        frame.origin = p
        return .success(())
    }

    func setSize(_ s: CGSize) -> Result<Void, WindowOpError> {
        if isGone { return .failure(.windowGone) }
        calls.append(.setSize(s))
        if let sizeError { return .failure(sizeError) }
        frame.size = CGSize(width: max(s.width, minSize.width), height: max(s.height, minSize.height))
        return .success(())
    }

    /// 기록된 호출 중 첫 `setSize` 인자.
    var firstSetSize: CGSize? {
        for call in calls {
            if case .setSize(let size) = call { return size }
        }
        return nil
    }
}
