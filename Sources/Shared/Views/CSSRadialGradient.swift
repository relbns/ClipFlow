import SwiftUI

/// CSS `radial-gradient(<rx>% <ry>% at <x>% <y>%, …)`: an ellipse whose radii are fractions of the
/// view's width and height, which SwiftUI's circular `RadialGradient` cannot express.
struct CSSRadialGradient: View {
    let gradient: Gradient
    /// Ellipse radii as fractions of width and height, e.g. (1.2, 0.8) for `120% 80%`.
    let radii: CGSize
    /// Center as a unit point, e.g. (0.3, 0.2) for `at 30% 20%`.
    let center: UnitPoint

    var body: some View {
        Canvas { context, size in
            let radiusX = max(1, radii.width * size.width)
            let radiusY = max(1, radii.height * size.height)
            context.translateBy(x: center.x * size.width, y: center.y * size.height)
            context.scaleBy(x: 1, y: radiusY / radiusX)
            let cover = max(size.width, size.height) * 4 * max(1, radiusX / radiusY)
            context.fill(
                Path(CGRect(x: -cover, y: -cover, width: cover * 2, height: cover * 2)),
                with: .radialGradient(gradient, center: .zero, startRadius: 0, endRadius: radiusX)
            )
        }
    }
}
