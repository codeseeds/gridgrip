// Support/AppIcon.svg 를 1024px PNG 로 렌더링한다. 사용: swift scripts/make-icon.swift <svg> <png>
import AppKit
let args = CommandLine.arguments
guard args.count == 3, let image = NSImage(contentsOfFile: args[1]) else { fatalError("usage: make-icon.swift <svg> <png>") }
let size = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4,
                           hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
image.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[2]))
