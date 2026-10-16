import CoreGraphics

/// 키보드 배치 10종 (9칸 + 전체).
public enum Placement: Equatable, CaseIterable {
    case topLeft, top, topRight
    case left, center, right
    case bottomLeft, bottom, bottomRight
    case fill
}

/// 다른 모니터로 보내기 방향. 모니터는 왼쪽→오른쪽 순서로 본다.
public enum DisplayDirection: Equatable {
    /// 왼쪽 모니터(쉼표)
    case previous
    /// 오른쪽 모니터(마침표)
    case next
}

/// 배치 동작 12종.
public enum PlacementCommand: Equatable {
    case place(Placement)
    case moveToDisplay(DisplayDirection)
}

/// 같은 키 반복 시 순환하는 비율.
public enum PlacementRatio {
    public static let cycle: [CGFloat] = [1.0 / 3, 1.0 / 2, 3.0 / 4]
}

extension PlacementCommand {
    /// `WindowAction` → 배치 명령 변환의 단일 지점. `undo`/`redo`는 nil.
    public init?(action: WindowAction) {
        switch action {
        case .topLeft: self = .place(.topLeft)
        case .top: self = .place(.top)
        case .topRight: self = .place(.topRight)
        case .left: self = .place(.left)
        case .center: self = .place(.center)
        case .right: self = .place(.right)
        case .bottomLeft: self = .place(.bottomLeft)
        case .bottom: self = .place(.bottom)
        case .bottomRight: self = .place(.bottomRight)
        case .fill: self = .place(.fill)
        case .previousDisplay: self = .moveToDisplay(.previous)
        case .nextDisplay: self = .moveToDisplay(.next)
        case .undo, .redo: return nil
        }
    }

    /// 디스패처에 등록할 동작 목록(12종, `WindowAction` 선언 순서).
    public static let handledActions: [WindowAction] = WindowAction.allCases.filter { PlacementCommand(action: $0) != nil }
}

extension Placement {
    /// 같은 키 반복 시 비율이 순환하는 배치. 가운데(J)·전체(F)는 비율을 쓰지 않는다.
    var usesRatioCycle: Bool {
        self != .center && self != .fill
    }

    /// 오른쪽 가장자리에 붙는 배치(I·K·M).
    var anchorsRight: Bool {
        self == .topRight || self == .right || self == .bottomRight
    }

    /// 아래쪽 가장자리에 붙는 배치(B·N·M).
    var anchorsBottom: Bool {
        self == .bottomLeft || self == .bottom || self == .bottomRight
    }
}
