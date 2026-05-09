import AppKit

/// Handles pasting clipboard items to applications
actor PasteEngine {

    /// Paste content to the frontmost application
    func paste(_ content: String) async {
        // Save current clipboard
        let savedClipboard = NSPasteboard.general.string(forType: .string)

        // Put new content on clipboard
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)

        // Wait briefly for clipboard to update
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms

        // Simulate Cmd+V
        await simulatePaste()

        // Restore original clipboard after delay
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        if let saved = savedClipboard {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(saved, forType: .string)
        }
    }

    @MainActor
    private func simulatePaste() {
        // Create Cmd+V key event
        let source = CGEventSource(stateID: .hidSystemState)

        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true) // Cmd
        let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)    // V
        let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false)

        cmdDown?.flags = .maskCommand
        vDown?.flags = .maskCommand

        cmdDown?.post(tap: .cghidEventTap)
        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)
        cmdUp?.post(tap: .cghidEventTap)
    }
}
