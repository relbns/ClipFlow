import AppKit

/// The menu bar glyph from the design's StatusBarStrip (two clipboards), as a template image.
enum StatusItemIcon {
    static func make(pointSize: CGFloat = 18) -> NSImage {
        let image = NSImage(size: NSSize(width: pointSize, height: pointSize), flipped: true) { rect in
            let scale = rect.width / 24
            let transform = AffineTransform(scaleByX: scale, byY: scale)

            let back = NSBezierPath(roundedRect: NSRect(x: 9, y: 6, width: 11, height: 13), xRadius: 2, yRadius: 2)
            back.transform(using: transform)
            back.lineWidth = 1.6 * scale
            back.lineCapStyle = .round
            back.lineJoinStyle = .round
            NSColor.black.setStroke()
            back.stroke()

            let front = NSBezierPath(roundedRect: NSRect(x: 4, y: 3, width: 11, height: 13), xRadius: 2, yRadius: 2)
            front.append(NSBezierPath(roundedRect: NSRect(x: 7.5, y: 2, width: 4, height: 2), xRadius: 0.7, yRadius: 0.7))
            front.transform(using: transform)
            NSColor.black.withAlphaComponent(0.95).setFill()
            front.fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "ClipFlow"
        return image
    }
}
