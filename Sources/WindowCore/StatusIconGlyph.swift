import CoreGraphics

/// 메뉴바 아이콘 한 칸. 좌표는 y 아래 방향(flipped)이고, 회전은 칸 중심 기준이다.
public struct StatusIconCell: Equatable {
    public let rect: CGRect
    public let opacity: CGFloat
    public let rotationDegrees: CGFloat
}

/// 앱 아이콘(Support/AppIcon.svg)의 3×3 격자를 배경 없이 메뉴바 크기로 옮긴 모양.
/// SVG 단위: 칸 16, 간격 4, 격자 56, 모서리 3. 가운데 칸만 흐리고(0.55) −12° 기울어져 (1, −0.5) 밀려 있다.
public enum StatusIconGlyph {
    public static let canvasSize: CGFloat = 18

    private static let gridUnits: CGFloat = 56
    private static let cellUnits: CGFloat = 16
    private static let strideUnits: CGFloat = 20
    private static let cornerUnits: CGFloat = 3
    private static let centerOffsetUnits = CGPoint(x: 1, y: -0.5)

    /// 칸 9개를 왼쪽 위부터 행 순서로 돌려준다. 격자는 캔버스의 1/18 여백 안을 채운다.
    public static func cells(canvasSize: CGFloat = canvasSize) -> [StatusIconCell] {
        let inset = canvasSize / 18
        let unit = (canvasSize - inset * 2) / gridUnits
        var cells: [StatusIconCell] = []
        for row in 0..<3 {
            for column in 0..<3 {
                let isCenter = row == 1 && column == 1
                var x = CGFloat(column) * strideUnits
                var y = CGFloat(row) * strideUnits
                if isCenter {
                    x += centerOffsetUnits.x
                    y += centerOffsetUnits.y
                }
                let rect = CGRect(x: inset + x * unit, y: inset + y * unit,
                                  width: cellUnits * unit, height: cellUnits * unit)
                cells.append(StatusIconCell(rect: rect,
                                            opacity: isCenter ? 0.55 : 1,
                                            rotationDegrees: isCenter ? -12 : 0))
            }
        }
        return cells
    }

    public static func cornerRadius(canvasSize: CGFloat = canvasSize) -> CGFloat {
        (canvasSize - canvasSize / 18 * 2) / gridUnits * cornerUnits
    }
}
