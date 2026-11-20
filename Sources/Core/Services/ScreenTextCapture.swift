import AppKit

/// The copy-text-from-screen hotkey: the user drags an area with the system's own selection, its text goes to the
/// clipboard (and so to history), and the capture itself is kept as an image clip when that setting is on.
@MainActor
enum ScreenTextCapture {
    static let saveScreenshotsKey = "ocrSaveScreenshots"
    private static let accessRequestedKey = "ocrScreenAccessRequested"
    private static var isCapturing = false

    static func run(monitor: ClipboardMonitor, defaults: UserDefaults = .standard) async {
        guard !isCapturing else { return }
        guard CGPreflightScreenCaptureAccess() else {
            // The first time, the system asks; after that, explain, since macOS may need a relaunch to see the grant.
            if defaults.bool(forKey: accessRequestedKey) {
                showPermissionAlert()
            } else {
                defaults.set(true, forKey: accessRequestedKey)
                CGRequestScreenCaptureAccess()
            }
            return
        }
        isCapturing = true
        defer { isCapturing = false }

        let file = FileManager.default.temporaryDirectory.appendingPathComponent("clipflow-capture-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: file) }
        await captureInteractively(to: file)
        guard let png = try? Data(contentsOf: file), !png.isEmpty else { return }

        let text = await TextRecognizer.recognize(imageData: png, languages: TextRecognizer.currentLanguages(defaults: defaults)) ?? ""
        if defaults.bool(forKey: saveScreenshotsKey) {
            monitor.recordScreenshot(png, recognizedText: text)
        }
        guard !text.isEmpty else {
            NSSound.beep()
            return
        }
        monitor.copy(text)
        Log.ui.info("Copied \(text.count, privacy: .public) characters of text from the screen")
    }

    /// `screencapture -i` shows the system's area selection; Escape leaves no file.
    private static func captureInteractively(to file: URL) async {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = ["-i", "-x", file.path]
            process.terminationHandler = { _ in continuation.resume() }
            do {
                try process.run()
            } catch {
                Log.ui.error("screencapture could not start: \(error.localizedDescription, privacy: .public)")
                continuation.resume()
            }
        }
    }

    private static func showPermissionAlert() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = L("ocr_permission_title")
        alert.informativeText = L("ocr_permission_body")
        alert.addButton(withTitle: L("ocr_permission_open"))
        alert.addButton(withTitle: L("ocr_permission_relaunch"))
        alert.addButton(withTitle: L("cancel"))
        switch alert.runModal() {
        case .alertFirstButtonReturn: openScreenRecordingSettings()
        case .alertSecondButtonReturn: relaunch()
        default: break
        }
    }

    /// macOS 14 reports a new Screen Recording grant only to a relaunched app.
    static func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }

    static func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}
