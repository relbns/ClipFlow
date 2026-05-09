import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
        }
        .frame(width: 500, height: 400)
    }
}

struct GeneralSettingsView: View {
    var body: some View {
        Form {
            Section {
                Text("ClipFlow")
                    .font(.largeTitle)
                Text("Modern Clipboard Manager + Text Expander")
                    .foregroundColor(.secondary)
            }

            Section("About") {
                LabeledContent("Version", value: "1.0.0 (1)")
                LabeledContent("Build", value: "Alpha")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

#Preview {
    SettingsView()
}
