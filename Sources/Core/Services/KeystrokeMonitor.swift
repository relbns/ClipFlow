import Cocoa
import Combine

/// Monitors all keystrokes system-wide using CGEventTap
@MainActor
class KeystrokeMonitor: ObservableObject {
    @Published var typedBuffer: String = ""
    @Published var isMonitoring: Bool = false

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let maxBufferLength = 50

    private let textExpansionEngine: TextExpansionEngine

    init(textExpansionEngine: TextExpansionEngine) {
        self.textExpansionEngine = textExpansionEngine
    }

    func startMonitoring() throws {
        NSLog("🎯 KeystrokeMonitor.startMonitoring() called")

        // Check Accessibility permissions
        let trusted = AXIsProcessTrusted()
        NSLog("🔐 AXIsProcessTrusted returned: \(trusted)")

        guard trusted else {
            NSLog("❌ Throwing accessibilityPermissionDenied error")
            throw ExpansionError.accessibilityPermissionDenied
        }
        NSLog("✅ Accessibility permission verified")

        // Create event tap for keyDown events
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
        NSLog("📊 Creating CGEvent tap with mask: \(eventMask)")

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { proxy, type, event, refcon in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<KeystrokeMonitor>.fromOpaque(refcon).takeUnretainedValue()

                // PERFORMANCE: Handle synchronously to avoid lag
                // Only the expansion itself happens asynchronously
                return monitor.handleKeyEventSync(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            NSLog("❌ CGEvent.tapCreate returned nil - failed to create event tap")
            throw ExpansionError.failedToCreateEventTap
        }
        NSLog("✅ CGEvent tap created successfully")

        self.eventTap = tap
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        NSLog("✅ Run loop source created")

        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        NSLog("✅ Run loop source added to current run loop")

        CGEvent.tapEnable(tap: tap, enable: true)
        NSLog("✅ Event tap enabled")

        isMonitoring = true
        NSLog("⌨️⌨️⌨️ Keystroke monitoring started successfully!")
        print("⌨️ Keystroke monitoring started")
    }

    func stopMonitoring() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            }
        }
        eventTap = nil
        runLoopSource = nil
        isMonitoring = false
        print("⌨️ Keystroke monitoring stopped")
    }

    // PERFORMANCE: Synchronous handler to avoid lag on every keystroke
    private func handleKeyEventSync(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent> {
        guard type == .keyDown else { return Unmanaged.passUnretained(event) }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        // Get typed character
        guard let chars = event.keyboardEventCharacters, !chars.isEmpty else {
            return Unmanaged.passUnretained(event)
        }

        // Handle special keys
        if isDeleteKey(keyCode) {
            Task { @MainActor in
                if !self.typedBuffer.isEmpty {
                    self.typedBuffer.removeLast()
                }
            }
            return Unmanaged.passUnretained(event)
        }

        if isResetKey(keyCode) {
            Task { @MainActor in
                self.typedBuffer = ""
            }
            return Unmanaged.passUnretained(event)
        }

        // Update buffer on main actor
        Task { @MainActor in
            // First append to buffer
            self.typedBuffer.append(chars)
            if self.typedBuffer.count > self.maxBufferLength {
                self.typedBuffer = String(self.typedBuffer.suffix(self.maxBufferLength))
            }

            // Try to match snippet (pass buffer including trigger char, and the trigger char separately)
            // The findMatch will check if buffer WITHOUT trigger ends with abbreviation
            if let match = self.textExpansionEngine.findMatch(in: self.typedBuffer, triggerChar: chars.last) {
                print("🎯 Match found: \(match.snippet.abbreviation) → \(match.snippet.title)")

                // Clear buffer
                self.typedBuffer = ""

                // Trigger expansion asynchronously (doesn't block typing)
                // Need to delete abbreviation + 1 for trigger character
                Task {
                    await self.textExpansionEngine.expand(match, includingTrigger: true)
                }
            }
        }

        return Unmanaged.passUnretained(event)
    }

    private func isDeleteKey(_ keyCode: Int64) -> Bool {
        return keyCode == 51 // Delete/Backspace
    }

    private func isResetKey(_ keyCode: Int64) -> Bool {
        return keyCode == 53 // Escape
    }
}

enum ExpansionError: Error {
    case accessibilityPermissionDenied
    case failedToCreateEventTap
}

extension CGEvent {
    var keyboardEventCharacters: String? {
        // Get Unicode string from event
        let maxLength = 10
        var length = 0
        var chars = [UniChar](repeating: 0, count: maxLength)

        keyboardGetUnicodeString(maxStringLength: maxLength, actualStringLength: &length, unicodeString: &chars)

        guard length > 0 else { return nil }
        return String(utf16CodeUnits: chars, count: length)
    }
}
