import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            AppearanceSettingsView()
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }

            TextExpansionSettingsView()
                .tabItem {
                    Label("Text Expansion", systemImage: "text.cursor")
                }

            HotkeySettingsView()
                .tabItem {
                    Label("Hotkeys", systemImage: "command")
                }

            SyncSettingsView()
                .tabItem {
                    Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                }

            AdvancedSettingsView()
                .tabItem {
                    Label("Advanced", systemImage: "gearshape.2")
                }
        }
        .frame(width: 550, height: 500)
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
