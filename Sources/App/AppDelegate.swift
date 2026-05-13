import Cocoa
import SwiftUI

/// Wrapper that dynamically updates layout direction based on language changes
struct DynamicLanguageWrapper<Content: View>: View {
    @EnvironmentObject var languageManager: LanguageManager
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .environment(\.layoutDirection, languageManager.layoutDirection)
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var clipboardMonitor: ClipboardMonitor?
    private var menuBarController: MenuBarController?
    private var menuBarPopover: NSPopover?
    private var hotkeyManager: HotkeyManager?
    private var appContextMonitor: AppContextMonitor?
    private var snippetEditorWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var aboutWindow: NSWindow?

    // Text Expansion
    private var textExpansionEngine: TextExpansionEngine?
    private var keystrokeMonitor: KeystrokeMonitor?
    private var hasShownAccessibilityAlert = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("🚀 ClipFlow applicationDidFinishLaunching started")

        // Create default snippets on first launch
        CoreDataStack.shared.createDefaultSnippetsIfNeeded()

        // Initialize services
        clipboardMonitor = ClipboardMonitor()
        appContextMonitor = AppContextMonitor()
        NSLog("✅ Clipboard and context monitors initialized")

        // Initialize text expansion
        let context = CoreDataStack.shared.viewContext
        textExpansionEngine = TextExpansionEngine(context: context)
        if let engine = textExpansionEngine {
            NSLog("✅ TextExpansionEngine created")
            keystrokeMonitor = KeystrokeMonitor(textExpansionEngine: engine)
            NSLog("✅ KeystrokeMonitor created")

            // Preload snippet cache for better performance
            engine.refreshCache()
            NSLog("✅ Snippet cache preloaded")
        } else {
            NSLog("❌ Failed to create TextExpansionEngine")
        }

        // Create menu bar controller (keep for fallback)
        if let monitor = clipboardMonitor {
            menuBarController = MenuBarController(clipboardMonitor: monitor, appDelegate: self)
        }

        // Setup hotkeys
        hotkeyManager = HotkeyManager.shared
        setupHotkeys()

        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "ClipFlow")
            button.target = self
            button.action = #selector(statusBarButtonClicked)
        }

        // Setup notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openPreferences),
            name: NSNotification.Name("OpenPreferences"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openSnippetEditor),
            name: NSNotification.Name("OpenSnippetEditor"),
            object: nil
        )

        // Start monitoring
        Task { @MainActor in
            NSLog("🔄 Starting monitors...")
            clipboardMonitor?.startMonitoring()
            appContextMonitor?.startMonitoring()
            NSLog("✅ Clipboard and context monitoring started")

            // Start text expansion if enabled (default: true)
            // Use explicit Bool conversion to avoid type mismatch crashes
            let expansionEnabled: Bool
            if let value = UserDefaults.standard.value(forKey: "textExpansionEnabled") as? Bool {
                expansionEnabled = value
            } else if let value = UserDefaults.standard.value(forKey: "textExpansionEnabled") as? Int {
                expansionEnabled = value != 0
            } else {
                expansionEnabled = true // default
                UserDefaults.standard.set(true, forKey: "textExpansionEnabled")
            }
            NSLog("📋 Text expansion setting: \(expansionEnabled)")
            if expansionEnabled {
                NSLog("🎯 Calling startTextExpansion()...")
                startTextExpansion()
            } else {
                NSLog("⚠️ Text expansion is disabled in settings")
            }
        }

        // Observe text expansion setting changes (specific key only)
        UserDefaults.standard.addObserver(
            self,
            forKeyPath: "textExpansionEnabled",
            options: [.new],
            context: nil
        )

        // Hide dock icon (menu bar app only)
        NSApp.setActivationPolicy(.accessory)
    }

    private func setupHotkeys() {
        hotkeyManager?.setupHotkeys(
            onMainMenu: { [weak self] in
                Task { @MainActor in
                    self?.showMenuPopover()
                }
            },
            onHistoryMenu: { [weak self] in
                Task { @MainActor in
                    self?.showMenuPopover()
                }
            },
            onSnippetsMenu: {
                print("📋 Snippets menu")
            },
            onSnippetEditor: { [weak self] in
                Task { @MainActor in
                    self?.openSnippetEditor()
                }
            },
            onClearHistory: { [weak self] in
                Task { @MainActor in
                    self?.clipboardMonitor?.clearHistory()
                }
            }
        )
    }

    @objc private func statusBarButtonClicked() {
        showMenuPopover()
    }

    private func showMenuPopover() {
        guard let clipboardMonitor = clipboardMonitor else { return }

        if menuBarPopover == nil {
            let popover = NSPopover()
            popover.behavior = .transient
            popover.animates = true

            let popoverView = MenuBarPopover(
                clipboardMonitor: clipboardMonitor,
                isPresented: Binding(
                    get: { popover.isShown },
                    set: { if !$0 { popover.performClose(nil) } }
                )
            )
            .cfAutoTheme()

            popover.contentViewController = NSHostingController(rootView: popoverView)
            menuBarPopover = popover
        }

        if let button = statusItem?.button {
            if menuBarPopover?.isShown == true {
                menuBarPopover?.performClose(nil)
            } else {
                menuBarPopover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }

    @objc func openPreferences() {
        print("🔧 AppDelegate.openPreferences() called")

        if settingsWindow == nil {
            print("📝 Creating new settings window")
            let languageManager = LanguageManager.shared
            let settingsView = DynamicLanguageWrapper {
                SettingsView()
                    .cfAutoTheme()
            }
            .environmentObject(languageManager)

            let hostingController = NSHostingController(rootView: settingsView)

            let window = NSWindow(contentViewController: hostingController)
            window.title = L("preferences")
            window.setContentSize(NSSize(width: 680, height: 540))
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.center()

            settingsWindow = window
            print("✅ Settings window created")
        } else {
            print("♻️ Reusing existing settings window")
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        print("✅ Settings window should be visible now")
    }

    @objc func openSnippetEditor() {
        print("📋 AppDelegate.openSnippetEditor() called")

        if snippetEditorWindow == nil {
            print("📝 Creating new editor window")
            let languageManager = LanguageManager.shared
            let editorView = DynamicLanguageWrapper {
                SnippetEditorView()
                    .cfAutoTheme()
                    .environment(\.managedObjectContext, CoreDataStack.shared.viewContext)
            }
            .environmentObject(languageManager)

            let hostingController = NSHostingController(rootView: editorView)

            let window = NSWindow(contentViewController: hostingController)
            window.title = L("snippet_editor")
            window.setContentSize(NSSize(width: 980, height: 640))
            window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
            window.center()

            snippetEditorWindow = window
            print("✅ Editor window created")
        } else {
            print("♻️ Reusing existing editor window")
        }

        snippetEditorWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        print("✅ Editor window should be visible now")
    }

    @objc func openAbout() {
        print("ℹ️ AppDelegate.openAbout() called")

        if aboutWindow == nil {
            print("📝 Creating new about window")
            let languageManager = LanguageManager.shared
            let aboutView = DynamicLanguageWrapper {
                AboutView()
                    .cfAutoTheme()
            }
            .environmentObject(languageManager)

            let hostingController = NSHostingController(rootView: aboutView)

            let window = NSWindow(contentViewController: hostingController)
            window.title = L("about_clipflow")
            window.setContentSize(NSSize(width: 560, height: 680))
            window.styleMask = [.titled, .closable]
            window.center()

            aboutWindow = window
            print("✅ About window created")
        } else {
            print("♻️ Reusing existing about window")
        }

        aboutWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        print("✅ About window should be visible now")
    }

    // MARK: - Text Expansion
    private func startTextExpansion() {
        NSLog("🎬 startTextExpansion() called")

        guard let monitor = keystrokeMonitor else {
            NSLog("❌ KeystrokeMonitor not initialized - cannot start text expansion")
            return
        }
        NSLog("✅ KeystrokeMonitor exists")

        // Check accessibility permission first
        let hasPermission = AXIsProcessTrusted()
        NSLog("🔐 Accessibility permission status: \(hasPermission)")

        // Don't restart if already monitoring
        if monitor.isMonitoring {
            NSLog("✅ Text expansion already running")
            return
        }
        NSLog("▶️ Attempting to start keystroke monitoring...")

        do {
            try monitor.startMonitoring()
            NSLog("✅✅✅ Text expansion started successfully!")
        } catch {
            NSLog("❌❌❌ Failed to start text expansion: \(error)")
            NSLog("Error type: \(type(of: error))")
            // Only show alert for permission denied (not other errors)
            if case ExpansionError.accessibilityPermissionDenied = error {
                NSLog("⚠️ Error is accessibilityPermissionDenied")
                // Only show alert once per session
                if !hasShownAccessibilityAlert {
                    hasShownAccessibilityAlert = true
                    NSLog("🚨 Showing accessibility alert")
                    showAccessibilityAlert()
                } else {
                    NSLog("⚠️ Permission still denied (alert already shown)")
                }
            } else {
                NSLog("⚠️ Error is NOT accessibilityPermissionDenied, it's: \(error)")
            }
        }
    }

    private func stopTextExpansion() {
        keystrokeMonitor?.stopMonitoring()
        print("🛑 Text expansion stopped")
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "textExpansionEnabled" {
            textExpansionSettingChanged()
        }
    }

    private func textExpansionSettingChanged() {
        let isEnabled = UserDefaults.standard.object(forKey: "textExpansionEnabled") as? Bool ?? true
        let isCurrentlyMonitoring = keystrokeMonitor?.isMonitoring ?? false

        // Only change state if needed
        if isEnabled && !isCurrentlyMonitoring {
            startTextExpansion()
        } else if !isEnabled && isCurrentlyMonitoring {
            stopTextExpansion()
        }
        // Otherwise, already in correct state - do nothing
    }

    private func showAccessibilityAlert() {
        // Defer alert to avoid being called during transaction
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText = "ClipFlow needs Accessibility permission to enable text expansion. Please grant permission in System Settings."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Cancel")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}
