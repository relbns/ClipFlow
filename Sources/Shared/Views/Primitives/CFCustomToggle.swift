import SwiftUI

/// Custom toggle component matching design spec
/// Matches the Toggle component from design/components/editor.jsx
///
/// IMPORTANT: This is NOT the system toggle!
/// Specs:
/// - Width: 32
/// - Height: 18
/// - Border radius: 999 (fully rounded)
/// - Background: accent when on, fill-3 when off
/// - Inner shadow: inset 0 0 0 .5px shadow-strong
/// - Thumb: 14×14 circle
/// - Position: top 2, left 16 when on, left 2 when off
/// - Transition: .18s
struct CFCustomToggle: View {
    @Environment(\.cfTheme) var theme

    @Binding var isOn: Bool

    var body: some View {
        ZStack(alignment: .leading) {
            // Track
            RoundedRectangle(cornerRadius: 999)
                .fill(isOn ? theme.accent : theme.fill3)
                .frame(width: 32, height: 18)
                .overlay(
                    RoundedRectangle(cornerRadius: 999)
                        .strokeBorder(theme.shadowStrong, lineWidth: 0.5)
                )

            // Thumb
            Circle()
                .fill(theme.knob)
                .frame(width: 14, height: 14)
                .shadow(color: theme.knobShadow.color, radius: theme.knobShadow.radius, x: theme.knobShadow.x, y: theme.knobShadow.y)
                .offset(x: isOn ? 16 : 2, y: 0)
                .animation(.easeInOut(duration: 0.18), value: isOn)
        }
        .frame(width: 32, height: 18)
        .contentShape(Rectangle())
        .onTapGesture {
            isOn.toggle()
        }
    }
}

// MARK: - Preview
#if DEBUG
struct CFCustomToggle_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VStack(spacing: 30) {
                Text("Custom Toggle Component")
                    .font(.title2)
                    .bold()

                HStack(spacing: 40) {
                    VStack(spacing: 8) {
                        CFCustomToggle(isOn: .constant(true))
                        Text("On")
                            .font(.caption)
                    }

                    VStack(spacing: 8) {
                        CFCustomToggle(isOn: .constant(false))
                        Text("Off")
                            .font(.caption)
                    }
                }

                // In context
                VStack(spacing: 12) {
                    HStack {
                        Text("Text expansion")
                            .font(.system(size: 13))
                            .foregroundColor(theme.text)
                        Spacer()
                        CFCustomToggle(isOn: .constant(true))
                    }

                    HStack {
                        Text("Sound feedback")
                            .font(.system(size: 13))
                            .foregroundColor(theme.text)
                        Spacer()
                        CFCustomToggle(isOn: .constant(false))
                    }

                    HStack {
                        Text("Backspace cancels")
                            .font(.system(size: 13))
                            .foregroundColor(theme.text)
                        Spacer()
                        CFCustomToggle(isOn: .constant(true))
                    }
                }
                .padding()
                .background(theme.surfaceDeep)
                .cornerRadius(8)
            }
            .padding(40)
            .frame(width: 500, height: 400)
            .background(theme.surface)
            .cfAutoTheme()
            .previewDisplayName("Toggle - Light")

            VStack(spacing: 30) {
                Text("Custom Toggle Component")
                    .font(.title2)
                    .bold()

                HStack(spacing: 40) {
                    VStack(spacing: 8) {
                        CFCustomToggle(isOn: .constant(true))
                        Text("On")
                            .font(.caption)
                    }

                    VStack(spacing: 8) {
                        CFCustomToggle(isOn: .constant(false))
                        Text("Off")
                            .font(.caption)
                    }
                }
            }
            .padding(40)
            .frame(width: 500, height: 400)
            .background(theme.surface)
            .cfAutoTheme()
            .preferredColorScheme(.dark)
            .previewDisplayName("Toggle - Dark")
        }
    }

    private static var theme: CFTheme { .dark }
}
#endif
