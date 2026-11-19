import Cocoa
import Combine
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

/// Window delegate for cleanup when Welcome window closes
class WelcomeWindowDelegate: NSObject, NSWindowDelegate {
    let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
        super.init()
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var menuBarPopover: NSPopover?
    private var popoverAnchorWindow: NSWindow?
    private var snippetEditorWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var aboutWindow: NSWindow?
    private var welcomeWindow: NSWindow?
    private var welcomeWindowDelegate: WelcomeWindowDelegate?

    private var clipboardMonitor: ClipboardMonitor!
    private var textExpansionEngine: TextExpansionEngine!
    private let keystrokeMonitor = KeystrokeMonitor()
    private let permissions = PermissionService.shared
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        ProcessInfo.processInfo.disableAutomaticTermination("ClipFlow runs in the menu bar without windows")
        AppDefaults.register()

        let stack = CoreDataStack.shared
        stack.prepareDefaultData()
        if let issue = stack.loadIssue {
            DispatchQueue.main.async { Self.showStoreAlert(for: issue) }
        }

        clipboardMonitor = ClipboardMonitor(context: stack.makeServiceContext())
        textExpansionEngine = TextExpansionEngine(context: stack.makeServiceContext())
        PasteEngine.shared.beforeWrite = { [weak self] in self?.clipboardMonitor.checkPasteboard() }
        keystrokeMonitor.onEvent = { [weak self] event in self?.textExpansionEngine.handle(event) }

        PasteCoordinator.shared.clipboardMonitor = clipboardMonitor
        PasteCoordinator.shared.closePopover = { [weak self] in self?.menuBarPopover?.performClose(nil) }
        PopoverNavigation.shared.clipboardMonitor = clipboardMonitor
        PopoverNavigation.shared.onClose = { [weak self] in self?.menuBarPopover?.performClose(nil) }

        setupStatusItem()
        setupHotkeys()
        setupNotifications()

        if UserDefaults.standard.bool(forKey: "startMonitoring") {
            clipboardMonitor.startMonitoring()
        }

        permissions.startWatching()
        permissions.$canListen
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateTextExpansionState() }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateTextExpansionState() }
            .store(in: &cancellables)

        let hasCompletedWelcome = UserDefaults.standard.bool(forKey: "hasCompletedWelcome")
        if !hasCompletedWelcome && !UserDefaults.standard.bool(forKey: "hasLaunchedBefore") {
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.openWelcome()
            }
        } else if isTextExpansionEnabled && !permissions.isGranted {
            permissions.request()
        }

        updateTextExpansionState()
        Log.app.info("ClipFlow started")
    }

    func applicationWillTerminate(_ notification: Notification) {
        keystrokeMonitor.stop()
        clipboardMonitor?.stopMonitoring()
    }

    private static func showStoreAlert(for issue: CoreDataStack.LoadIssue) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        switch issue {
        case .newerVersion:
            alert.messageText = L("store_newer_title")
            alert.informativeText = L("store_newer_message")
        case .movedAside(let url):
            alert.messageText = L("store_moved_title")
            alert.informativeText = L("store_moved_message", url.path)
            alert.addButton(withTitle: L("show_in_finder"))
            alert.addButton(withTitle: "OK")
        }
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn, case .movedAside(let url) = issue {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    // MARK: - Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "ClipFlow")
            button.target = self
            button.action = #selector(statusBarButtonClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    private func setupHotkeys() {
        HotkeyManager.shared.setupHotkeys(
            onHistoryMenu: { [weak self] in self?.showMenuPopover() },
            onSnippetEditor: { [weak self] in self?.openSnippetEditor() },
            onClearHistory: { [weak self] in self?.clipboardMonitor.clearHistory() }
        )
    }

    private func setupNotifications() {
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(openPreferences), name: NSNotification.Name("OpenPreferences"), object: nil)
        center.addObserver(self, selector: #selector(openSnippetEditor), name: NSNotification.Name("OpenSnippetEditor"), object: nil)
        center.addObserver(self, selector: #selector(openAbout), name: NSNotification.Name("OpenAbout"), object: nil)
    }

    // MARK: - Text expansion

    private var isTextExpansionEnabled: Bool {
        UserDefaults.standard.bool(forKey: "textExpansionEnabled")
    }

    /// Idempotent: starts the tap once expansion is on and Input Monitoring is granted, stops it otherwise.
    private func updateTextExpansionState() {
        let shouldRun = isTextExpansionEnabled && permissions.canListen
        if shouldRun && !keystrokeMonitor.isMonitoring {
            if !keystrokeMonitor.start() {
                Log.expansion.error("Text expansion could not start although permission is granted")
            }
        } else if !shouldRun && keystrokeMonitor.isMonitoring {
            keystrokeMonitor.stop()
        }
    }

    // MARK: - Popover

    @objc private func statusBarButtonClicked() {
        showMenuPopover()
    }

    private func showMenuPopover() {
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
            NotificationCenter.default.addObserver(forName: NSPopover.didCloseNotification, object: popover, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.popoverAnchorWindow?.orderOut(nil)
                    PopoverNavigation.shared.popoverDidClose()
                }
            }
            menuBarPopover = popover
        }

        guard let popover = menuBarPopover else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            PasteCoordinator.shared.rememberFrontmostApp()
            PopoverNavigation.shared.popoverWillShow()
            let anchor = popoverAnchor()
            popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    /// The status item, or the top of the mouse's screen when the item is hidden (e.g. by a menu bar manager).
    private func popoverAnchor() -> NSView {
        if let button = statusItem?.button, let window = button.window,
           window.occlusionState.contains(.visible),
           NSScreen.screens.contains(where: { $0.frame.intersects(window.frame) }) {
            return button
        }

        let anchor = popoverAnchorWindow ?? {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1, height: 1), styleMask: .borderless, backing: .buffered, defer: false)
            window.isOpaque = false
            window.backgroundColor = .clear
            window.level = .statusBar
            window.ignoresMouseEvents = true
            window.isReleasedWhenClosed = false
            return window
        }()
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        let top = screen?.visibleFrame.maxY ?? mouse.y
        anchor.setFrameOrigin(NSPoint(x: mouse.x, y: top - 1))
        anchor.orderFrontRegardless()
        popoverAnchorWindow = anchor
        Log.ui.info("Status item is not visible, opening the popover under the menu bar at the mouse")
        return anchor.contentView ?? NSView()
    }

    // MARK: - Windows

    @objc func openPreferences() {
        if settingsWindow == nil {
            let settingsView = DynamicLanguageWrapper {
                SettingsView()
                    .cfAutoTheme()
            }
            .environmentObject(LanguageManager.shared)

            settingsWindow = makeWindow(
                rootView: settingsView,
                title: L("preferences"),
                size: NSSize(width: 760, height: 620),
                style: [.titled, .closable, .miniaturizable]
            )
        }
        present(settingsWindow)
    }

    @objc func openSnippetEditor() {
        if snippetEditorWindow == nil {
            let editorView = DynamicLanguageWrapper {
                SnippetEditorView()
                    .cfAutoTheme()
                    .environment(\.managedObjectContext, CoreDataStack.shared.viewContext)
            }
            .environmentObject(LanguageManager.shared)

            snippetEditorWindow = makeWindow(
                rootView: editorView,
                title: L("snippet_editor"),
                size: NSSize(width: 1080, height: 700),
                style: [.titled, .closable, .resizable, .miniaturizable]
            )
        }
        present(snippetEditorWindow)
    }

    @objc func openAbout() {
        if aboutWindow == nil {
            let aboutView = DynamicLanguageWrapper {
                AboutView()
                    .cfAutoTheme()
            }
            .environmentObject(LanguageManager.shared)

            aboutWindow = makeWindow(
                rootView: aboutView,
                title: L("about_clipflow"),
                size: NSSize(width: 560, height: 520),
                style: [.titled, .closable]
            )
        }
        present(aboutWindow)
    }

    @objc func openWelcome() {
        if welcomeWindow == nil {
            let close: () -> Void = { [weak self] in
                self?.welcomeWindow?.close()
            }
            let welcomeView = DynamicLanguageWrapper {
                WelcomeView(
                    isPresented: Binding(get: { true }, set: { if !$0 { close() } }),
                    onGetStarted: close
                )
                .cfAutoTheme()
            }
            .environmentObject(LanguageManager.shared)

            let window = makeWindow(
                rootView: welcomeView,
                title: "Welcome to ClipFlow",
                size: NSSize(width: 780, height: 560),
                style: [.titled, .closable]
            )
            let delegate = WelcomeWindowDelegate { [weak self] in
                self?.welcomeWindow = nil
                self?.welcomeWindowDelegate = nil
            }
            window.delegate = delegate
            window.isReleasedWhenClosed = false
            welcomeWindowDelegate = delegate
            welcomeWindow = window
        }
        present(welcomeWindow)
    }

    private func makeWindow<Content: View>(rootView: Content, title: String, size: NSSize, style: NSWindow.StyleMask) -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: rootView))
        window.title = title
        window.setContentSize(size)
        window.styleMask = style
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }

    private func present(_ window: NSWindow?) {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
