import SwiftUI

/// The brand mark: two stacked clipboards in an indigo gradient, drawn from the design's 64×64 SVG.
struct ClipFlowMark: View {
    var size: CGFloat = 64
    /// Draws the dark rounded tile behind the clipboards, as in the app icon.
    var rounded: Bool = true

    var body: some View {
        Canvas { context, canvasSize in
            context.scaleBy(x: canvasSize.width / 64, y: canvasSize.height / 64)
            Self.draw(in: &context, rounded: rounded)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    static func draw(in context: inout GraphicsContext, rounded: Bool) {
        if rounded {
            context.fill(
                Path(roundedRect: CGRect(x: 0, y: 0, width: 64, height: 64), cornerRadius: 14, style: .continuous),
                with: .linearGradient(BrandPalette.markTile, startPoint: .zero, endPoint: CGPoint(x: 64, y: 64))
            )
        }

        var back = context
        back.translateBy(x: 28, y: 16)
        back.translateBy(x: 14, y: 18)
        back.rotate(by: .degrees(8))
        back.translateBy(x: -14, y: -18)
        let backFill = GraphicsContext.Shading.linearGradient(
            BrandPalette.markBack, startPoint: CGPoint(x: 14, y: 14), endPoint: CGPoint(x: 50, y: 50)
        )
        var backBody = back
        backBody.opacity = 0.85
        backBody.fill(Path(roundedRect: CGRect(x: 0, y: 2, width: 28, height: 36), cornerRadius: 5), with: backFill)
        backBody.fill(Path(roundedRect: CGRect(x: 9, y: -2, width: 10, height: 6), cornerRadius: 1.4), with: backFill)
        line(in: back, x: 6, y: 14, width: 12, height: 2, opacity: 0.55)
        line(in: back, x: 6, y: 20, width: 16, height: 2, opacity: 0.40)

        var front = context
        front.translateBy(x: 8, y: 12)
        let frontFill = GraphicsContext.Shading.linearGradient(
            BrandPalette.markFront, startPoint: CGPoint(x: 6, y: 6), endPoint: CGPoint(x: 58, y: 58)
        )
        let frontBody = Path(roundedRect: CGRect(x: 0, y: 2, width: 32, height: 40), cornerRadius: 6)
        front.fill(frontBody, with: frontFill)
        front.fill(Path(roundedRect: CGRect(x: 10, y: -2, width: 12, height: 7), cornerRadius: 1.6), with: frontFill)
        line(in: front, x: 12, y: -1, width: 8, height: 3, opacity: 0.25, radius: 1)
        line(in: front, x: 6, y: 14, width: 20, height: 2.2, opacity: 0.90)
        line(in: front, x: 6, y: 20, width: 16, height: 2.2, opacity: 0.70)
        line(in: front, x: 6, y: 26, width: 12, height: 2.2, opacity: 0.55)
        var gloss = front
        gloss.opacity = 0.06
        gloss.fill(frontBody, with: .color(.white))
    }

    private static func line(in context: GraphicsContext, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, opacity: Double, radius: CGFloat? = nil) {
        var context = context
        context.opacity = opacity
        context.fill(
            Path(roundedRect: CGRect(x: x, y: y, width: width, height: height), cornerRadius: radius ?? height / 2),
            with: .color(.white)
        )
    }
}

/// The About window's hero: the mark on a 128pt brand-gradient tile with gloss and a tinted shadow.
struct ClipFlowHero: View {
    var size: CGFloat = 128

    var body: some View {
        let radius = size * 28 / 128
        let tile = RoundedRectangle(cornerRadius: radius, style: .continuous)
        ZStack {
            tile.fill(LinearGradient(gradient: BrandPalette.heroTile, startPoint: .topLeading, endPoint: .bottomTrailing))
            ClipFlowMark(size: size * 92 / 128, rounded: false)
            RoundedRectangle(cornerRadius: radius - 1, style: .continuous)
                .fill(LinearGradient(stops: [
                    .init(color: .white.opacity(0.22), location: 0),
                    .init(color: .clear, location: 0.4)
                ], startPoint: .top, endPoint: .bottom))
                .padding(1)
            tile.strokeBorder(
                LinearGradient(stops: [
                    .init(color: .white.opacity(0.18), location: 0),
                    .init(color: .clear, location: 0.06)
                ], startPoint: .top, endPoint: .bottom),
                lineWidth: 1
            )
        }
        .frame(width: size, height: size)
        .shadow(color: BrandPalette.heroShadow, radius: size * 19 / 128, y: size * 30 / 128)
        .accessibilityHidden(true)
    }
}
