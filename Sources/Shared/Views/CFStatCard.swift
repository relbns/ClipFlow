import SwiftUI

/// Statistics card component for 2×2 grid in Snippet Editor inspector
/// Shows a large value with a small label below
struct CFStatCard: View {
    let value: String
    let label: String

    @Environment(\.cfTheme) var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(theme.textStrong)

            Text(label)
                .font(.system(size: 10.5))
                .foregroundColor(theme.textSubtle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(theme.fillSoft)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(theme.strokeSoft, lineWidth: 1)
        )
        .cornerRadius(6)
    }
}

// MARK: - Preview
#Preview("Stat Cards - Dark") {
    VStack(spacing: 16) {
        Text("Snippet Statistics Grid")
            .font(.headline)
            .padding(.bottom, 8)

        LazyVGrid(columns: [GridItem(), GridItem()], spacing: 8) {
            CFStatCard(value: "184", label: "expansions")
            CFStatCard(value: "27 min", label: "time saved")
            CFStatCard(value: "Mail", label: "top app")
            CFStatCard(value: "May 9", label: "last used")
        }

        Divider()
            .padding(.vertical, 8)

        Text("Various Value Types")
            .font(.headline)
            .padding(.bottom, 8)

        LazyVGrid(columns: [GridItem(), GridItem()], spacing: 8) {
            CFStatCard(value: "1,247", label: "total uses")
            CFStatCard(value: "3.2 hrs", label: "saved")
            CFStatCard(value: "Xcode", label: "top location")
            CFStatCard(value: "2 days ago", label: "last sync")
        }
    }
    .padding()
    .frame(width: 320)
    .background(Color(red: 0.11, green: 0.11, blue: 0.13))
    .cfAutoTheme()
}

#Preview("Stat Cards - Light") {
    LazyVGrid(columns: [GridItem(), GridItem()], spacing: 8) {
        CFStatCard(value: "184", label: "expansions")
        CFStatCard(value: "27 min", label: "time saved")
        CFStatCard(value: "Mail", label: "top app")
        CFStatCard(value: "Yesterday", label: "last used")
    }
    .padding()
    .frame(width: 280)
    .background(Color(red: 0.96, green: 0.96, blue: 0.97))
    .cfAutoTheme()
}
