import SwiftUI

/// Step indicator component for Welcome screen
/// Shows numbered circle with three states: default, active, done
struct CFStepIndicator: View {
    enum StepState {
        case `default`
        case active
        case done
    }

    let number: Int
    let state: StepState
    let title: String
    let bodyText: String

    @Environment(\.cfTheme) var theme

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Circle indicator
            ZStack {
                Circle()
                    .fill(circleBackground)
                    .frame(width: 28, height: 28)
                    .shadow(
                        color: state == .active ?
                            BrandPalette.stepActiveGlow :
                            .clear,
                        radius: 7,
                        x: 0,
                        y: 3
                    )

                if state == .done {
                    // Checkmark icon
                    CFIcon(type: .check, size: 14, stroke: 2.4)
                        .foregroundColor(theme.textStrong)
                } else {
                    // Number
                    Text("\(number)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(theme.textStrong)
                }
            }
            .frame(width: 32, alignment: .center)  // Container width for grid alignment

            // Content
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(theme.textStrong)

                Text(bodyText)
                    .font(.system(size: 12))
                    .foregroundColor(theme.textMuted)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
        .background(state == .active ? theme.fillSoft : .clear)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    state == .active ?
                        BrandPalette.stepActiveBorder :
                        .clear,
                    lineWidth: 1
                )
        )
        .cornerRadius(10)
    }

    private var circleBackground: some ShapeStyle {
        switch state {
        case .default:
            return AnyShapeStyle(theme.fill1)

        case .active:
            return AnyShapeStyle(LinearGradient(gradient: BrandPalette.stepActive, startPoint: .top, endPoint: .bottom))

        case .done:
            return AnyShapeStyle(BrandPalette.success)
        }
    }
}

// MARK: - Preview
#Preview("Step States - Dark") {
    VStack(spacing: 16) {
        Text("Welcome Screen Steps")
            .font(.headline)
            .padding(.bottom, 8)

        VStack(spacing: 12) {
            CFStepIndicator(
                number: 1,
                state: .done,
                title: "Pin ClipFlow to your menubar",
                bodyText: "ClipFlow lives up here — there's no Dock icon. Drag the menubar item to where you'd like."
            )

            CFStepIndicator(
                number: 2,
                state: .active,
                title: "Grant Accessibility permission",
                bodyText: "Required so snippets can expand as you type. We never read passwords or secure fields."
            )

            CFStepIndicator(
                number: 3,
                state: .default,
                title: "Try your first snippet",
                bodyText: "We've added .dd for today's date. Type it anywhere, then press space."
            )
        }
    }
    .padding()
    .frame(width: 400)
    .background(CFTheme.dark.surface)
    .cfAutoTheme()
}

#Preview("Step States - Light") {
    VStack(spacing: 12) {
        CFStepIndicator(
            number: 1,
            state: .done,
            title: "Step completed",
            bodyText: "This step has been completed successfully."
        )

        CFStepIndicator(
            number: 2,
            state: .active,
            title: "Current step",
            bodyText: "This is the active step with highlighted border and glow."
        )

        CFStepIndicator(
            number: 3,
            state: .default,
            title: "Upcoming step",
            bodyText: "This step is not yet active."
        )
    }
    .padding()
    .frame(width: 400)
    .background(CFTheme.light.surface)
    .cfAutoTheme()
}
