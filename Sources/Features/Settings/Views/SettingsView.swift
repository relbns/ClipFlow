import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label(L("general"), systemImage: "gear")
                }

            AppearanceSettingsView()
                .tabItem {
                    Label(L("appearance"), systemImage: "paintbrush")
                }

            TextExpansionSettingsView()
                .tabItem {
                    Label(L("text_expansion"), systemImage: "text.cursor")
                }

            HotkeySettingsView()
                .tabItem {
                    Label(L("hotkeys"), systemImage: "command")
                }

            SyncSettingsView()
                .tabItem {
                    Label(L("sync"), systemImage: "arrow.triangle.2.circlepath")
                }

            AdvancedSettingsView()
                .tabItem {
                    Label(L("advanced"), systemImage: "gearshape.2")
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
                Text(L("app_tagline"))
                    .foregroundColor(.secondary)
            }

            Section(L("language")) {
                Picker(L("interface_language"), selection: $preferredLanguage) {
                    Text(L("system_default")).tag("system")
                    Text(L("english")).tag("en")
                    Text(L("hebrew")).tag("he")
                }

                Text(L("restart_required"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section(L("clipboard_history")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L("maximum_items"))

                    HStack {
                        Slider(value: $maxHistoryItems, in: 10...100, step: 5)
                        Text("\(Int(maxHistoryItems))")
                            .frame(width: 40)
                    }
                }

                Toggle(L("remove_duplicates"), isOn: .constant(true))
                Toggle(L("move_used_to_top"), isOn: .constant(true))
            }

            Section(L("startup")) {
                Toggle(L("launch_at_login"), isOn: $launchAtLogin)
                Toggle(L("start_monitoring"), isOn: .constant(true))
            }

            Section(L("about")) {
                LabeledContent(L("version"), value: "1.0.0 (1)")
                LabeledContent(L("build"), value: "Alpha")
                Button(L("view_on_github")) {
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
