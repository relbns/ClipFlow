// Renders the DMG window background at 1x and 2x: swift scripts/render-dmg-background.swift <output-folder>
import AppKit

let size = NSSize(width: 660, height: 400)
let folder = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Packaging")

func render(scale: CGFloat) -> Data? {
    let pixels = NSSize(width: size.width * scale, height: size.height * scale)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(pixels.width), pixelsHigh: Int(pixels.height),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { return nil }
    rep.size = size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    NSGradient(colors: [NSColor(srgbRed: 0.97, green: 0.97, blue: 0.99, alpha: 1), NSColor(srgbRed: 0.92, green: 0.92, blue: 0.97, alpha: 1)])?
        .draw(in: NSRect(origin: .zero, size: size), angle: 90)

    let accent = NSColor(srgbRed: 0.37, green: 0.45, blue: 0.89, alpha: 1)
    let arrow = NSBezierPath()
    arrow.lineWidth = 5
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    arrow.move(to: NSPoint(x: 265, y: 230))
    arrow.line(to: NSPoint(x: 390, y: 230))
    arrow.move(to: NSPoint(x: 370, y: 248))
    arrow.line(to: NSPoint(x: 392, y: 230))
    arrow.line(to: NSPoint(x: 370, y: 212))
    accent.setStroke()
    arrow.stroke()

    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let lines: [(String, CGFloat, NSFont, NSColor)] = [
        ("Drag ClipFlow to Applications to install it", 106, .systemFont(ofSize: 15, weight: .medium), NSColor(white: 0.2, alpha: 1)),
        ("גררו את ClipFlow לתיקיית Applications כדי להתקין", 82, .systemFont(ofSize: 14), NSColor(white: 0.4, alpha: 1))
    ]
    for (text, y, font, color) in lines {
        NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph])
            .draw(in: NSRect(x: 0, y: y, width: size.width, height: 24))
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

for (scale, name) in [(CGFloat(1), "dmg-background.png"), (CGFloat(2), "dmg-background@2x.png")] {
    guard let data = render(scale: scale) else { fatalError("could not render \(name)") }
    try data.write(to: folder.appendingPathComponent(name))
}
print("Rendered \(folder.path)/dmg-background.png and @2x")
