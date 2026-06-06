import SwiftUI

/// Version tag badge (e.g., ALPHA, BETA)
/// Spec: uppercase 10.5/600, amber color-mix background
struct CFVersionTag: View {
    enum TagType {
        case alpha
        case beta
        case stable

        var label: String {
            switch self {
            case .alpha: return "ALPHA"
            case .beta: return "BETA"
            case .stable: return "STABLE"
            }
        }
    }

    let type: TagType

    var body: some View {
        Text(type.label)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundColor(Color(red: 0.83, green: 0.68, blue: 0.38))  // oklch(.7 .15 60) amber
            .textCase(.uppercase)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Color(red: 0.85, green: 0.68, blue: 0.36).opacity(0.25)  // oklch(.7 .17 60) 25%
            )
            .cornerRadius(4)
    }
}

#Preview {
    HStack(spacing: 12) {
        CFVersionTag(type: .alpha)
        CFVersionTag(type: .beta)
        CFVersionTag(type: .stable)
    }
    .padding()
    .background(Color(white: 0.15))
}
