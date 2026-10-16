import CoreGraphics
import XCTest
import WindowCore

final class StatusIconGlyphTests: XCTestCase {
    func testNineCellsWithOnlyCenterFadedAndTilted() {
        let cells = StatusIconGlyph.cells()
        XCTAssertEqual(cells.count, 9)

        let center = cells[4]
        XCTAssertEqual(center.opacity, 0.55, accuracy: 0.0001)
        XCTAssertEqual(center.rotationDegrees, -12, accuracy: 0.0001)

        for (index, cell) in cells.enumerated() where index != 4 {
            XCTAssertEqual(cell.opacity, 1, "칸 \(index)")
            XCTAssertEqual(cell.rotationDegrees, 0, "칸 \(index)")
        }
    }

    func testGridMatchesAppIconProportions() {
        // AppIcon.svg: 칸 16, 간격 4, 격자 56 (단위). 18pt 캔버스에서 격자는 1pt 여백 안의 16pt.
        let cells = StatusIconGlyph.cells(canvasSize: 18)
        let unit: CGFloat = 16 / 56
        let first = cells[0].rect
        XCTAssertEqual(first.minX, 1, accuracy: 0.0001)
        XCTAssertEqual(first.minY, 1, accuracy: 0.0001)
        XCTAssertEqual(first.width, 16 * unit, accuracy: 0.0001)
        XCTAssertEqual(first.height, 16 * unit, accuracy: 0.0001)
        XCTAssertEqual(cells[1].rect.minX - first.maxX, 4 * unit, accuracy: 0.0001)
        XCTAssertEqual(cells[3].rect.minY - first.maxY, 4 * unit, accuracy: 0.0001)
        XCTAssertEqual(cells[8].rect.maxX, 17, accuracy: 0.0001)
        XCTAssertEqual(cells[8].rect.maxY, 17, accuracy: 0.0001)
        XCTAssertEqual(StatusIconGlyph.cornerRadius(canvasSize: 18), 3 * unit, accuracy: 0.0001)
    }

    func testCenterCellIsNudgedLikeAppIcon() {
        // AppIcon.svg 의 translate(1 -0.5): 오른쪽 1, 위로 0.5 (y 아래 방향 좌표).
        let cells = StatusIconGlyph.cells(canvasSize: 18)
        let unit: CGFloat = 16 / 56
        XCTAssertEqual(cells[4].rect.minX, 1 + (20 + 1) * unit, accuracy: 0.0001)
        XCTAssertEqual(cells[4].rect.minY, 1 + (20 - 0.5) * unit, accuracy: 0.0001)
    }

    func testScalesWithCanvas() {
        let small = StatusIconGlyph.cells(canvasSize: 18)
        let large = StatusIconGlyph.cells(canvasSize: 36)
        for (a, b) in zip(small, large) {
            XCTAssertEqual(b.rect.minX, a.rect.minX * 2, accuracy: 0.0001)
            XCTAssertEqual(b.rect.width, a.rect.width * 2, accuracy: 0.0001)
        }
    }
}
