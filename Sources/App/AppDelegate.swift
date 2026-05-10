import Cocoa
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var clipboardMonitor: ClipboardMonitor?
    private var menuBarController: MenuBarController?
    private var hotkeyManager: HotkeyManager?
    private var appContextMonitor: AppContextMonitor?
    private var snippetEditorWindow: NSWindow?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize services
        clipboardMonitor = ClipboardMonitor()
        appContextMonitor = AppContextMonitor()

        // Create menu bar controller
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
            button.action = #selector(statusBarButtonClicked)
        }

        // Start monitoring
        Task { @MainActor in
            clipboardMonitor?.startMonitoring()
            appContextMonitor?.startMonitoring()
        }

        // Hide dock icon (menu bar app only)
        NSApp.setActivationPolicy(.accessory)
    }

    private func setupHotkeys() {
        hotkeyManager?.setupHotkeys(
            onMainMenu: { [weak self] in
                Task { @MainActor in
                    self?.showMenu()
                }
            },
            onHistoryMenu: { [weak self] in
                Task { @MainActor in
                    self?.showMenu()
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
        showMenu()
    }

    private func showMenu() {
        guard let menu = menuBarController?.buildMainMenu() else { return }

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc func openPreferences() {
        print("🔧 AppDelegate.openPreferences() called")
        if settingsWindow == nil {
            print("📝 Creating new settings window")
            let settingsView = SettingsView()
            let hostingController = NSHostingController(rootView: settingsView)

            let window = NSWindow(contentViewController: hostingController)
            window.title = L("preferences")
            window.setContentSize(NSSize(width: 550, height: 500))
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
            let editorView = SnippetEditorView()
                .environment(\.managedObjectContext, CoreDataStack.shared.viewContext)

            let hostingController = NSHostingController(rootView: editorView)

            let window = NSWindow(contentViewController: hostingController)
            window.title = L("snippet_editor")
            window.setContentSize(NSSize(width: 900, height: 650))
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
}
