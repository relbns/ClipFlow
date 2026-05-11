import SwiftUI

struct ExclusionsSettingsView: View {
    @AppStorage("excludedApps") private var excludedAppsJSON = "[]"
    @State private var excludedApps: [ExcludedApp] = []

    @Environment(\.cfTheme) var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(L("exclusions"))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(theme.textStrong)

                    Text("Prevent ClipFlow from monitoring clipboard or expanding snippets in specific apps")
                        .font(.system(size: 13))
                        .foregroundColor(theme.textSubtle)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                // Clipboard Monitoring Exclusions
                VStack(alignment: .leading, spacing: 16) {
                    CFSettingsRow(
                        label: "Exclude from clipboard monitoring",
                        hint: "Apps where clipboard history won't be recorded"
                    ) {
                        VStack(alignment: .leading, spacing: 8) {
                            if excludedApps.filter({ $0.excludeFromHistory }).isEmpty {
                                Text("No exclusions")
                                    .font(.system(size: 12))
                                    .foregroundColor(theme.textFaint)
                            } else {
                                ForEach(excludedApps.filter({ $0.excludeFromHistory })) { app in
                                    CFPill(
                                        text: app.name,
                                        closable: true,
                                        onClose: {
                                            removeApp(app)
                                        }
                                    )
                                }
                            }

                            CFAddPill(text: "+ Add app") {
                                addAppForHistory()
                            }
                        }
                    }

                    // Text Expansion Exclusions
                    CFSettingsRow(
                        label: "Exclude from text expansion",
                        hint: "Apps where snippets won't expand",
                        isLast: true
                    ) {
                        VStack(alignment: .leading, spacing: 8) {
                            if excludedApps.filter({ $0.excludeFromExpansion }).isEmpty {
                                Text("No exclusions")
                                    .font(.system(size: 12))
                                    .foregroundColor(theme.textFaint)
                            } else {
                                ForEach(excludedApps.filter({ $0.excludeFromExpansion })) { app in
                                    CFPill(
                                        text: app.name,
                                        closable: true,
                                        onClose: {
                                            removeApp(app)
                                        }
                                    )
                                }
                            }

                            CFAddPill(text: "+ Add app") {
                                addAppForExpansion()
                            }
                        }
                    }
                }
                .padding(20)
                .background(theme.surface)
                .cornerRadius(12)
                .padding(.horizontal, 24)

                // Recommended Exclusions Banner
                CFBanner.info(
                    icon: AnyView(CFIcon(type: .lock, size: 18, stroke: 1.8)),
                    title: "Security recommendation",
                    message: "Consider excluding password managers like 1Password, Bitwarden, or LastPass to prevent sensitive data from being copied to history."
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .background(theme.surfaceDeep)
        .onAppear {
            loadExcludedApps()
        }
    }

    private func loadExcludedApps() {
        guard let data = excludedAppsJSON.data(using: .utf8),
              let apps = try? JSONDecoder().decode([ExcludedApp].self, from: data) else {
            return
        }
        excludedApps = apps
    }

    private func saveExcludedApps() {
        guard let data = try? JSONEncoder().encode(excludedApps),
              let json = String(data: data, encoding: .utf8) else {
            return
        }
        excludedAppsJSON = json
    }

    private func addAppForHistory() {
        pickApp { app in
            var newApp = app
            newApp.excludeFromHistory = true
            excludedApps.append(newApp)
            saveExcludedApps()
        }
    }

    private func addAppForExpansion() {
        pickApp { app in
            var newApp = app
            newApp.excludeFromExpansion = true
            excludedApps.append(newApp)
            saveExcludedApps()
        }
    }

    private func removeApp(_ app: ExcludedApp) {
        excludedApps.removeAll { $0.id == app.id }
        saveExcludedApps()
    }

    private func pickApp(completion: @escaping (ExcludedApp) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            if let bundle = Bundle(url: url) {
                let bundleID = bundle.bundleIdentifier ?? url.lastPathComponent
                let appName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                    ?? url.deletingPathExtension().lastPathComponent

                let app = ExcludedApp(
                    id: UUID(),
                    bundleID: bundleID,
                    name: appName,
                    excludeFromHistory: false,
                    excludeFromExpansion: false
                )
                completion(app)
            }
        }
    }
}

struct ExcludedApp: Codable, Identifiable {
    let id: UUID
    let bundleID: String
    let name: String
    var excludeFromHistory: Bool
    var excludeFromExpansion: Bool
}

#Preview {
    ExclusionsSettingsView()
        .cfAutoTheme()
}
