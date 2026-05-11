import SwiftUI

// MARK: - Toggle
struct CFToggle: View {
    @Binding var isOn: Bool
    @Environment(\.cfTheme) var theme

    var body: some View {
        Button(action: { isOn.toggle() }) {
            ZStack(alignment: isOn ? .trailing : .leading) {
                // Track
                Capsule()
                    .fill(isOn ? theme.accent : theme.fill3)
                    .frame(width: 32, height: 18)
                    .overlay(
                        Capsule()
                            .strokeBorder(theme.shadowStrong, lineWidth: 0.5)
                    )

                // Knob
                Circle()
                    .fill(theme.knob)
                    .frame(width: 14, height: 14)
                    .shadow(
                        color: theme.knobShadow.color,
                        radius: theme.knobShadow.radius,
                        x: theme.knobShadow.x,
                        y: theme.knobShadow.y
                    )
                    .padding(2)
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.18, dampingFraction: 0.8), value: isOn)
    }
}

// MARK: - Select (Dropdown-style)
struct CFSelect: View {
    let value: String
    var action: (() -> Void)? = nil
    @Environment(\.cfTheme) var theme

    var body: some View {
        Button(action: { action?() }) {
            HStack(spacing: 8) {
                Text(value)
                    .font(.system(size: 13))
                    .foregroundColor(theme.textStrong)
                    .frame(maxWidth: .infinity, alignment: .leading)

                CFIcon(type: .chevronDown, size: 12, stroke: 1.6)
                    .foregroundColor(theme.textMuted)
            }
            .padding(.horizontal, 8)
            .frame(height: 26)
            .background(theme.btnBg)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(theme.stroke, lineWidth: 1)
            )
            .shadow(
                color: theme.btnShadow.color,
                radius: theme.btnShadow.radius,
                x: theme.btnShadow.x,
                y: theme.btnShadow.y
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Input Field
struct CFInput: View {
    @Binding var text: String
    var placeholder: String = ""
    var mono: Bool = false
    var prefix: String? = nil
    var suffix: AnyView? = nil
    var dir: TextAlignment = .leading
    @Environment(\.cfTheme) var theme

    var body: some View {
        HStack(spacing: 6) {
            if let prefix = prefix {
                Text(prefix)
                    .font(.system(size: 12))
                    .foregroundColor(theme.textSubtle)
            }

            TextField(placeholder, text: $text)
                .font(.system(size: 13, design: mono ? .monospaced : .default))
                .foregroundColor(theme.text)
                .textFieldStyle(.plain)
                .multilineTextAlignment(dir)

            if let suffix = suffix {
                suffix
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 26)
        .background(theme.inputBg)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(theme.stroke, lineWidth: 1)
        )
    }
}

// MARK: - Field Label + Control
struct CFField<Content: View>: View {
    let label: String
    var hint: String? = nil
    @ViewBuilder let content: () -> Content
    @Environment(\.cfTheme) var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11.5))
                .foregroundColor(theme.textMuted)

            content()

            if let hint = hint {
                Text(hint)
                    .font(.system(size: 11))
                    .foregroundColor(theme.textFaint)
            }
        }
    }
}

// MARK: - Slider
struct CFSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double> = 10...100
    var displayValue: String? = nil
    @Environment(\.cfTheme) var theme

    private var percent: Double {
        (value - range.lowerBound) / (range.upperBound - range.lowerBound)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Min label
            Text("\(Int(range.lowerBound))")
                .font(.system(size: 11))
                .foregroundColor(theme.textSubtle)
                .frame(width: 22, alignment: .trailing)
                .monospacedDigit()

            // Track + Knob
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(theme.fill2)
                        .frame(height: 4)

                    // Filled track
                    Capsule()
                        .fill(theme.accent)
                        .frame(width: geometry.size.width * percent, height: 4)

                    // Knob
                    Circle()
                        .fill(theme.knob)
                        .frame(width: 14, height: 14)
                        .shadow(
                            color: theme.knobShadow.color,
                            radius: theme.knobShadow.radius,
                            x: theme.knobShadow.x,
                            y: theme.knobShadow.y
                        )
                        .offset(x: geometry.size.width * percent - 7)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { drag in
                                    let newPercent = max(0, min(1, drag.location.x / geometry.size.width))
                                    value = range.lowerBound + (range.upperBound - range.lowerBound) * newPercent
                                }
                        )
                }
            }
            .frame(height: 14)

            // Max label
            Text("\(Int(range.upperBound))")
                .font(.system(size: 11))
                .foregroundColor(theme.textSubtle)
                .frame(width: 22)
                .monospacedDigit()

            // Current value display
            Text(displayValue ?? "\(Int(value))")
                .font(.system(size: 12))
                .foregroundColor(theme.textStrong)
                .monospacedDigit()
                .frame(minWidth: 32)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(theme.fill1)
                .cornerRadius(4)
        }
        .frame(maxWidth: 360)
    }
}

// MARK: - Segmented Control (Grid-based)
struct CFSegmentedControl: View {
    @Binding var selection: Int
    let options: [String]
    var columns: Int = 3
    @Environment(\.cfTheme) var theme

    var body: some View {
        let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 4), count: columns)

        LazyVGrid(columns: gridColumns, spacing: 4) {
            ForEach(0..<options.count, id: \.self) { index in
                let isSelected = index == selection
                Button(action: { selection = index }) {
                    Text(options[index])
                        .font(.system(size: isSelected ? 12 : 11))
                        .foregroundColor(isSelected ? theme.textStrong : theme.textSubtle)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, isSelected ? 6 : 5)
                        .background(isSelected ? AnyShapeStyle(theme.segSelected) : AnyShapeStyle(Color.clear))
                        .cornerRadius(5)
                        .shadow(
                            color: isSelected ? theme.segShadow.color : .clear,
                            radius: theme.segShadow.radius,
                            x: theme.segShadow.x,
                            y: theme.segShadow.y
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(theme.inputBg)
        .cornerRadius(7)
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(theme.stroke, lineWidth: 1)
        )
        .animation(.spring(response: 0.18), value: selection)
    }
}

// MARK: - Settings Row (Two-column layout)
struct CFSettingsRow<Content: View>: View {
    let label: String
    var hint: String? = nil
    var isLast: Bool = false
    @ViewBuilder let content: () -> Content
    @Environment(\.cfTheme) var theme

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            // Left column - label
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13))
                    .foregroundColor(theme.text)

                if let hint = hint {
                    Text(hint)
                        .font(.system(size: 11.5))
                        .foregroundColor(theme.textSubtle)
                }
            }
            .frame(width: 180, alignment: .topLeading)
            .padding(.top, 4)

            // Right column - control
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 12)
        .background(
            VStack(spacing: 0) {
                Spacer()
                if !isLast {
                    Rectangle()
                        .fill(theme.strokeSoft)
                        .frame(height: 1)
                }
            }
        )
    }
}

// MARK: - Preview
#if DEBUG
struct CFControls_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ControlsShowcase()
                .cfAutoTheme()
                .previewDisplayName("Light")

            ControlsShowcase()
                .cfAutoTheme()
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark")
        }
    }

    struct ControlsShowcase: View {
        @State private var toggleOn = true
        @State private var text = "Hello World"
        @State private var sliderValue: Double = 50
        @State private var segmentSelection = 1
        @Environment(\.cfTheme) var theme

        var body: some View {
            ScrollView {
                VStack(spacing: 24) {
                    Text("ClipFlow Controls")
                        .font(.title2)
                        .bold()
                        .foregroundColor(theme.textStrong)

                    VStack(alignment: .leading, spacing: 16) {
                        CFField(label: "Toggle", hint: "On/off switch") {
                            HStack {
                                CFToggle(isOn: $toggleOn)
                                Text(toggleOn ? "On" : "Off")
                                    .font(.system(size: 12))
                                    .foregroundColor(theme.textMuted)
                            }
                        }

                        CFField(label: "Select", hint: "Dropdown picker") {
                            CFSelect(value: "Space, Tab or Enter")
                        }

                        CFField(label: "Text Input") {
                            CFInput(text: $text, placeholder: "Enter text...")
                        }

                        CFField(label: "Monospace Input") {
                            CFInput(text: .constant(".sig"), placeholder: "Abbreviation", mono: true, prefix: ".")
                        }

                        CFField(label: "Slider") {
                            CFSlider(value: $sliderValue, range: 10...100)
                        }

                        CFField(label: "Segmented Control") {
                            CFSegmentedControl(
                                selection: $segmentSelection,
                                options: ["Space", "Tab", "Enter", "Punct.", "Any", "Manual"],
                                columns: 3
                            )
                        }
                    }
                    .padding()
                    .background(theme.surface)
                    .cornerRadius(12)

                    // Settings Row Example
                    VStack(spacing: 0) {
                        CFSettingsRow(label: "Text expansion", hint: "Replace abbreviations with snippets as you type.") {
                            HStack {
                                CFToggle(isOn: $toggleOn)
                                Text("On")
                                    .font(.system(size: 12))
                                    .foregroundColor(theme.textMuted)
                            }
                        }

                        CFSettingsRow(label: "Sound feedback", hint: "Quiet click when an abbreviation expands.", isLast: true) {
                            CFToggle(isOn: .constant(false))
                        }
                    }
                    .padding()
                    .background(theme.surface)
                    .cornerRadius(12)
                }
                .padding(30)
            }
            .frame(width: 600, height: 800)
            .background(theme.surfaceDeep)
        }
    }
}
#endif
