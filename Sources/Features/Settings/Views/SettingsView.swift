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
    @AppStorage("preferredLanguage") private var preferredLanguage = "system"
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("maxHistoryItems") private var maxHistoryItems = 30.0

    var body: some View {
        Form {
            Section {
                Text("ClipFlow")
                    .font(.largeTitle)
                Text("Modern Clipboard Manager + Text Expander")
                    .foregroundColor(.secondary)
            }

            Section("Language") {
                Picker("Interface Language:", selection: $preferredLanguage) {
                    Text("System Default").tag("system")
                    Text("English").tag("en")
                    Text("עברית (Hebrew)").tag("he")
                }

                Text("Restart required to apply language changes")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Clipboard History") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Maximum items:")

                    HStack {
                        Slider(value: $maxHistoryItems, in: 10...100, step: 5)
                        Text("\(Int(maxHistoryItems))")
                            .frame(width: 40)
                    }
                }

                Toggle("Remove duplicates automatically", isOn: .constant(true))
                Toggle("Move used items to top", isOn: .constant(true))
            }

            Section("Startup") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                Toggle("Start monitoring on launch", isOn: .constant(true))
            }

            Section("About") {
                LabeledContent("Version", value: "1.0.0 (1)")
                LabeledContent("Build", value: "Alpha")
                Button("View on GitHub") {
                    if let url = URL(string: "https://github.com/relbns/ClipFlow") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

#Preview {
    SettingsView()
}
