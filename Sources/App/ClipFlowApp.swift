import SwiftUI

@main
struct ClipFlowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var languageManager = LanguageManager.shared

    var body: some Scene {
        Settings {
            SettingsView()
                .environment(\.layoutDirection, languageManager.layoutDirection)
                .environmentObject(languageManager)
        }
    }
}
