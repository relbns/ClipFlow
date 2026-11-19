import SwiftUI

@main
struct ClipFlowApp: App {
    // Declared first so it runs before the delegate or anything else reads a setting.
    private let previousSettings: Void = PreviousBundleDefaults.migrateIfNeeded()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Preferences is an AppKit window owned by AppDelegate; ⌘, opens that one, never a second copy.
        Settings { EmptyView() }
            .commands {
                CommandGroup(replacing: .appSettings) {
                    Button(L("menu_preferences")) {
                        NSApp.sendAction(#selector(AppDelegate.openPreferences), to: nil, from: nil)
                    }
                    .keyboardShortcut(",")
                }
            }
    }
}
