import AppKit

/// Handles pasting clipboard items to applications
actor PasteEngine {

    /// Paste content to the frontmost application
    func paste(_ content: String) async {
        // Check for {cursor} marker
        let cursorMarker = "{cursor}"
        let hasCursor = content.contains(cursorMarker)

        // Remove cursor marker and calculate position
        let cleanContent = content.replacingOccurrences(of: cursorMarker, with: "")
        let cursorOffset = hasCursor ? content.distance(from: content.range(of: cursorMarker)!.upperBound, to: content.endIndex) : 0

        // Save current clipboard
        let savedClipboard = NSPasteboard.general.string(forType: .string)

        // Put new content on clipboard
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(cleanContent, forType: .string)

        // Wait briefly for clipboard to update
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms

        // Simulate Cmd+V
        await simulatePaste()

        // If cursor marker exists, move cursor to that position
        if hasCursor && cursorOffset > 0 {
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms wait for paste
            await moveCursorLeft(count: cursorOffset)
        }

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

    @MainActor
    private func moveCursorLeft(count: Int) {
        let source = CGEventSource(stateID: .hidSystemState)

        for _ in 0..<count {
            let leftDown = CGEvent(keyboardEventSource: source, virtualKey: 0x7B, keyDown: true)  // Left arrow
            let leftUp = CGEvent(keyboardEventSource: source, virtualKey: 0x7B, keyDown: false)

            leftDown?.post(tap: .cghidEventTap)
            leftUp?.post(tap: .cghidEventTap)

            // Small delay between arrow presses
            usleep(5000) // 5ms
        }
    }
}
