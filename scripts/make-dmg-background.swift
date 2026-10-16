// DMG 창 배경(600×440pt)을 1x·2x PNG 로 그린다. 사용: swift scripts/make-dmg-background.swift <출력 폴더>
// 아이콘 위치는 scripts/dmg-settings.py 의 icon_locations 와 맞춘다 (앱 160,160 / Applications 440,160).
// 사용자 Finder 에 경로 막대·상태 막대가 켜져 있어도 문구가 가려지지 않도록 내용은 위쪽 320pt 안에 둔다.
import AppKit

let width: CGFloat = 600
let height: CGFloat = 440
let iconCenterY: CGFloat = 160

let background = NSColor(srgbRed: 0xf5 / 255, green: 0xf5 / 255, blue: 0xf7 / 255, alpha: 1)
let accent = NSColor(srgbRed: 0xe5 / 255, green: 0x53 / 255, blue: 0x1a / 255, alpha: 1) // AppIcon.svg 배경 아래쪽 색
let titleColor = NSColor(srgbRed: 0x1d / 255, green: 0x1d / 255, blue: 0x1f / 255, alpha: 1)
let subtitleColor = NSColor(srgbRed: 0x6e / 255, green: 0x6e / 255, blue: 0x73 / 255, alpha: 1)

func drawCentered(_ text: String, font: NSFont, color: NSColor, top: CGFloat) {
    let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
    let size = (text as NSString).size(withAttributes: attributes)
    (text as NSString).draw(at: NSPoint(x: (width - size.width) / 2, y: top), withAttributes: attributes)
}

func render(scale: CGFloat, to url: URL) throws {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(width * scale), pixelsHigh: Int(height * scale),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: width, height: height)
    NSGraphicsContext.saveGraphicsState()
    // Finder 좌표(위가 0)에 맞춰 뒤집은 컨텍스트에 그린다.
    NSGraphicsContext.current = NSGraphicsContext(cgContext: NSGraphicsContext(bitmapImageRep: rep)!.cgContext, flipped: true)
    let transform = NSAffineTransform()
    transform.translateX(by: 0, yBy: height)
    transform.scaleX(by: 1, yBy: -1)
    transform.concat()

    background.setFill()
    NSRect(x: 0, y: 0, width: width, height: height).fill()

    // 앱 → Applications 화살표
    let arrow = NSBezierPath()
    arrow.lineWidth = 3
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    arrow.move(to: NSPoint(x: 250, y: iconCenterY))
    arrow.line(to: NSPoint(x: 348, y: iconCenterY))
    arrow.move(to: NSPoint(x: 336, y: iconCenterY - 11))
    arrow.line(to: NSPoint(x: 350, y: iconCenterY))
    arrow.line(to: NSPoint(x: 336, y: iconCenterY + 11))
    accent.setStroke()
    arrow.stroke()

    drawCentered("Drag GridGrip to Applications to install",
                 font: .systemFont(ofSize: 16, weight: .semibold), color: titleColor, top: 268)
    drawCentered("Then open GridGrip and allow Accessibility access in System Settings.",
                 font: .systemFont(ofSize: 12), color: subtitleColor, top: 294)

    NSGraphicsContext.restoreGraphicsState()
    try rep.representation(using: .png, properties: [:])!.write(to: url)
}

let args = CommandLine.arguments
guard args.count == 2 else { fatalError("usage: make-dmg-background.swift <output-dir>") }
let dir = URL(fileURLWithPath: args[1])
try render(scale: 1, to: dir.appendingPathComponent("dmg-background.png"))
try render(scale: 2, to: dir.appendingPathComponent("dmg-background@2x.png"))
