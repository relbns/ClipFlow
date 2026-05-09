import Cocoa
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var clipboardMonitor: ClipboardMonitor?
    private var menuBarController: MenuBarController?
    private var hotkeyManager: HotkeyManager?
    private var appContextMonitor: AppContextMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize services
        clipboardMonitor = ClipboardMonitor()
        appContextMonitor = AppContextMonitor()

        // Create menu bar controller
        if let monitor = clipboardMonitor {
            menuBarController = MenuBarController(clipboardMonitor: monitor)
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
            onSnippetsMenu: { [weak self] in
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
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func openSnippetEditor() {
        // TODO: Implement snippet editor window
        print("📝 Opening snippet editor...")
    }
}
