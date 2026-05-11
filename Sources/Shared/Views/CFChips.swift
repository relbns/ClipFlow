import SwiftUI

// MARK: - Variable Chip (for snippet editor)
struct CFVarChip: View {
    let text: String
    var action: (() -> Void)? = nil
    @Environment(\.cfTheme) var theme

    var body: some View {
        Button(action: { action?() }) {
            Text(text)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Color(red: 0.86, green: 0.12, blue: 0.72)) // oklch(.86 .12 272)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(
                    theme.accentMix(percent: 30)
                )
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(theme.accentMix(percent: 35), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Keyboard Shortcut Badge
struct CFKBD: View {
    let text: String
    var dim: Bool = false
    @Environment(\.cfTheme) var theme

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundColor(dim ? theme.textSubtle : theme.textMid)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .frame(minWidth: 16)
            .background(dim ? theme.fillSoft : theme.fill2)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(theme.stroke, lineWidth: 1)
            )
            .shadow(
                color: theme.shadowStrong,
                radius: 0,
                x: 0,
                y: -1
            )
    }
}

// MARK: - Pill (for tags, excluded apps, etc.)
struct CFPill: View {
    let text: String
    var icon: AnyView? = nil
    var closable: Bool = false
    var onClose: (() -> Void)? = nil
    @Environment(\.cfTheme) var theme

    var body: some View {
        HStack(spacing: 6) {
            if let icon = icon {
                icon
                    .frame(width: 12, height: 12)
            }

            Text(text)
                .font(.system(size: 12))
                .foregroundColor(theme.text)

            if closable {
                Button(action: { onClose?() }) {
                    Text("×")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(theme.textFaint)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, icon != nil ? 24 : 8)
        .padding(.trailing, 8)
        .padding(.vertical, 3)
        .background(theme.fill1)
        .cornerRadius(999)
        .overlay(
            RoundedRectangle(cornerRadius: 999)
                .strokeBorder(theme.stroke, lineWidth: 1)
        )
        .overlay(
            Group {
                if let icon = icon {
                    HStack {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(theme.fill2)
                            .frame(width: 12, height: 12)
                            .overlay(icon)
                            .padding(.leading, 6)
                        Spacer()
                    }
                }
            }
        )
    }
}

// MARK: - Dashed Add Pill
struct CFAddPill: View {
    let text: String
    var action: (() -> Void)? = nil
    @Environment(\.cfTheme) var theme

    var body: some View {
        Button(action: { action?() }) {
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(theme.textMuted)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.clear)
                .cornerRadius(999)
                .overlay(
                    RoundedRectangle(cornerRadius: 999)
                        .stroke(theme.stroke, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Count Badge (for group item counts)
struct CFCountBadge: View {
    let count: Int
    @Environment(\.cfTheme) var theme

    var body: some View {
        Text("\(count)")
            .font(.system(size: 11))
            .foregroundColor(theme.textSubtle)
            .monospacedDigit()
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(theme.fill1)
            .cornerRadius(999)
    }
}

// MARK: - Status Chip (for snippet editor status bar)
struct CFStatusChip: View {
    enum Status {
        case saved
        case saving
        case error
    }

    let status: Status
    @Environment(\.cfTheme) var theme

    private var color: Color {
        switch status {
        case .saved:
            return Color(red: 0.7, green: 0.17, blue: 0.45, opacity: 1.0) // green
        case .saving:
            return Color(red: 0.7, green: 0.17, blue: 0.70, opacity: 1.0) // amber
        case .error:
            return Color(red: 0.7, green: 0.17, blue: 0.30, opacity: 1.0) // red
        }
    }

    private var label: String {
        switch status {
        case .saved: return "Saved"
        case .saving: return "Saving..."
        case .error: return "Error"
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)

            Text(label)
                .font(.system(size: 11))
                .foregroundColor(theme.text)
        }
    }
}

// MARK: - Alpha/Beta Tag (for version badge)
struct CFVersionTag: View {
    enum TagType {
        case alpha
        case beta
        case dev

        var label: String {
            switch self {
            case .alpha: return "Alpha"
            case .beta: return "Beta"
            case .dev: return "Dev"
            }
        }

        var color: Color {
            switch self {
            case .alpha: return Color(red: 0.7, green: 0.17, blue: 0.60, opacity: 1.0) // amber
            case .beta: return Color(red: 0.6, green: 0.17, blue: 0.72, opacity: 1.0) // purple
            case .dev: return Color(red: 0.7, green: 0.14, blue: 0.50, opacity: 1.0) // green
            }
        }
    }

    let type: TagType
    @Environment(\.cfTheme) var theme

    var body: some View {
        Text(type.label)
            .font(.system(size: 10.5, weight: .semibold))
            .tracking(0.6)
            .textCase(.uppercase)
            .foregroundColor(type.color)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(type.color.opacity(0.25))
            .cornerRadius(999)
    }
}

// MARK: - Preview
#if DEBUG
struct CFChips_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ChipsShowcase()
                .cfAutoTheme()
                .previewDisplayName("Light")

            ChipsShowcase()
                .cfAutoTheme()
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark")
        }
    }

    struct ChipsShowcase: View {
        @Environment(\.cfTheme) var theme

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("ClipFlow Chips & Badges")
                        .font(.title2)
                        .bold()
                        .foregroundColor(theme.textStrong)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Variable Chips")
                            .font(.headline)
                            .foregroundColor(theme.text)

                        HStack(spacing: 6) {
                            CFVarChip(text: "{date}")
                            CFVarChip(text: "{time}")
                            CFVarChip(text: "{clipboard}")
                            CFVarChip(text: "{cursor}")
                            CFVarChip(text: "{prompt:Name}")
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Keyboard Shortcuts")
                            .font(.headline)
                            .foregroundColor(theme.text)

                        HStack(spacing: 8) {
                            CFKBD(text: "⌘E")
                            CFKBD(text: "⌘,")
                            CFKBD(text: "1", dim: true)
                            CFKBD(text: "⌘F", dim: false)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Pills")
                            .font(.headline)
                            .foregroundColor(theme.text)

                        HStack(spacing: 6) {
                            CFPill(text: "1Password", closable: true)
                            CFPill(text: "Terminal", closable: true)
                            CFPill(text: "Bitwarden", closable: true)
                            CFAddPill(text: "+ Add app")
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Count Badges")
                            .font(.headline)
                            .foregroundColor(theme.text)

                        HStack(spacing: 10) {
                            CFCountBadge(count: 14)
                            CFCountBadge(count: 3)
                            CFCountBadge(count: 122)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Status Chips")
                            .font(.headline)
                            .foregroundColor(theme.text)

                        HStack(spacing: 12) {
                            CFStatusChip(status: .saved)
                            CFStatusChip(status: .saving)
                            CFStatusChip(status: .error)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Version Tags")
                            .font(.headline)
                            .foregroundColor(theme.text)

                        HStack(spacing: 8) {
                            CFVersionTag(type: .alpha)
                            CFVersionTag(type: .beta)
                            CFVersionTag(type: .dev)
                        }
                    }
                }
                .padding(30)
            }
            .frame(width: 600, height: 700)
            .background(theme.surfaceDeep)
        }
    }
}
#endif
