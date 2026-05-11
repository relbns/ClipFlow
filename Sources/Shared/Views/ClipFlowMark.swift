import SwiftUI

/// ClipFlow brand mark - two overlapping clipboards with gradient
/// Based on the design file's logo implementation
struct ClipFlowMark: View {
    var size: CGFloat = 64
    var rounded: Bool = true
    var showBackground: Bool = true

    @Environment(\.cfTheme) var theme

    var body: some View {
        Canvas { context, canvasSize in
            // Background rounded rectangle if requested
            if showBackground && rounded {
                let bgRect = CGRect(x: 0, y: 0, width: 64, height: 64)
                let bgPath = Path(roundedRect: bgRect, cornerRadius: 14)

                // Background gradient: oklch(.32 .04 280) to oklch(.20 .03 270)
                let bgGradient = Gradient(colors: [
                    Color(red: 0.32, green: 0.04, blue: 0.28),
                    Color(red: 0.20, green: 0.03, blue: 0.27)
                ])

                context.fill(bgPath, with: .linearGradient(
                    bgGradient,
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: 64, y: 64)
                ))
            }

            // Define gradients
            // Front: oklch(.74 .17 280) to oklch(.55 .19 270)
            let frontGradient = Gradient(colors: [
                Color(red: 0.54, green: 0.37, blue: 0.91),  // oklch(.74 .17 280) approx
                Color(red: 0.38, green: 0.26, blue: 0.77)   // oklch(.55 .19 270) approx
            ])

            // Back: oklch(.66 .17 280) to oklch(.50 .18 270)
            let backGradient = Gradient(colors: [
                Color(red: 0.46, green: 0.30, blue: 0.82),  // oklch(.66 .17 280) approx
                Color(red: 0.32, green: 0.20, blue: 0.68)   // oklch(.50 .18 270) approx
            ])

            // Draw back clipboard (rotated)
            var backContext = context
            backContext.translateBy(x: 28, y: 16)
            backContext.rotate(by: .degrees(8))

            // Back clipboard body
            let backBody = Path(roundedRect: CGRect(x: 0, y: 2, width: 28, height: 36), cornerRadius: 5)
            backContext.opacity = 0.85
            backContext.fill(backBody, with: .linearGradient(
                backGradient,
                startPoint: CGPoint(x: 0, y: 2),
                endPoint: CGPoint(x: 28, y: 38)
            ))

            // Back clip head
            let backClipHead = Path(roundedRect: CGRect(x: 9, y: -2, width: 10, height: 6), cornerRadius: 1.4)
            backContext.fill(backClipHead, with: .linearGradient(
                backGradient,
                startPoint: CGPoint(x: 9, y: -2),
                endPoint: CGPoint(x: 19, y: 4)
            ))

            // Back lines
            backContext.opacity = 0.55
            backContext.fill(Path(roundedRect: CGRect(x: 6, y: 14, width: 12, height: 2), cornerRadius: 1), with: .color(.white))
            backContext.opacity = 0.40
            backContext.fill(Path(roundedRect: CGRect(x: 6, y: 20, width: 16, height: 2), cornerRadius: 1), with: .color(.white))

            // Draw front clipboard
            var frontContext = context
            frontContext.translateBy(x: 8, y: 12)

            // Front clipboard body
            let frontBody = Path(roundedRect: CGRect(x: 0, y: 2, width: 32, height: 40), cornerRadius: 6)
            frontContext.opacity = 1.0
            frontContext.fill(frontBody, with: .linearGradient(
                frontGradient,
                startPoint: CGPoint(x: 0, y: 2),
                endPoint: CGPoint(x: 32, y: 42)
            ))

            // Front clip head
            let frontClipHead = Path(roundedRect: CGRect(x: 10, y: -2, width: 12, height: 7), cornerRadius: 1.6)
            frontContext.fill(frontClipHead, with: .linearGradient(
                frontGradient,
                startPoint: CGPoint(x: 10, y: -2),
                endPoint: CGPoint(x: 22, y: 5)
            ))

            // White accent on clip head
            frontContext.opacity = 0.25
            frontContext.fill(Path(roundedRect: CGRect(x: 12, y: -1, width: 8, height: 3), cornerRadius: 1), with: .color(.white))

            // Front page lines
            frontContext.opacity = 0.90
            frontContext.fill(Path(roundedRect: CGRect(x: 6, y: 14, width: 20, height: 2.2), cornerRadius: 1.1), with: .color(.white))
            frontContext.opacity = 0.70
            frontContext.fill(Path(roundedRect: CGRect(x: 6, y: 20, width: 16, height: 2.2), cornerRadius: 1.1), with: .color(.white))
            frontContext.opacity = 0.55
            frontContext.fill(Path(roundedRect: CGRect(x: 6, y: 26, width: 12, height: 2.2), cornerRadius: 1.1), with: .color(.white))

            // Glossy edge on front
            frontContext.opacity = 0.06
            frontContext.fill(frontBody, with: .color(.white))

            // Top gloss overlay on background
            if showBackground && rounded {
                let glossRect = CGRect(x: 0, y: 0, width: 64, height: 64)
                let glossPath = Path(roundedRect: glossRect, cornerRadius: 14)
                let glossGradient = Gradient(colors: [
                    Color.white.opacity(0.22),
                    Color.clear
                ])

                context.opacity = 1.0
                context.fill(glossPath, with: .linearGradient(
                    glossGradient,
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: 0, y: 32)
                ))
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Menu Bar Icon Variant
extension ClipFlowMark {
    /// Mini version for status bar (16-20px)
    static func menuBarIcon(size: CGFloat = 18) -> some View {
        ClipFlowMark(size: size, rounded: false, showBackground: false)
            .frame(width: size, height: size)
    }

    /// Hero version for About window (128px with shadow)
    static func heroIcon(size: CGFloat = 128) -> some View {
        ClipFlowMark(size: size, rounded: true, showBackground: true)
            .shadow(color: Color(red: 0.45, green: 0.19, blue: 0.27, opacity: 0.55), radius: 50, x: 0, y: 30)
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.21875)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
    }
}

// MARK: - Preview
#if DEBUG
struct ClipFlowMark_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            Text("ClipFlow Mark Variants")
                .font(.title)
                .bold()

            HStack(spacing: 40) {
                VStack {
                    ClipFlowMark(size: 32, rounded: false, showBackground: false)
                    Text("32px • No BG")
                        .font(.caption)
                }

                VStack {
                    ClipFlowMark(size: 64, rounded: true, showBackground: true)
                    Text("64px • Rounded BG")
                        .font(.caption)
                }

                VStack {
                    ClipFlowMark.heroIcon(size: 96)
                    Text("96px • Hero")
                        .font(.caption)
                }
            }

            HStack(spacing: 30) {
                VStack {
                    ClipFlowMark.menuBarIcon(size: 16)
                    Text("MenuBar 16px")
                        .font(.caption2)
                }

                VStack {
                    ClipFlowMark.menuBarIcon(size: 20)
                    Text("MenuBar 20px")
                        .font(.caption2)
                }

                VStack {
                    ClipFlowMark.menuBarIcon(size: 24)
                    Text("MenuBar 24px")
                        .font(.caption2)
                }
            }
        }
        .padding(60)
        .frame(width: 700, height: 600)
        .background(Color(red: 0.1, green: 0.1, blue: 0.12))
    }
}
#endif
