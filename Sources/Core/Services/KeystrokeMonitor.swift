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
        // Check Accessibility permissions
        let trusted = AXIsProcessTrusted()
        guard trusted else {
            throw ExpansionError.accessibilityPermissionDenied
        }

        // Create event tap for keyDown events
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { proxy, type, event, refcon in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<KeystrokeMonitor>.fromOpaque(refcon).takeUnretainedValue()

                Task { @MainActor in
                    return await monitor.handleKeyEvent(proxy: proxy, type: type, event: event)
                }

                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            throw ExpansionError.failedToCreateEventTap
        }

        self.eventTap = tap
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        isMonitoring = true
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

    private func handleKeyEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) async -> Unmanaged<CGEvent> {
        guard type == .keyDown else { return Unmanaged.passUnretained(event) }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        // Get typed character
        guard let chars = event.keyboardEventCharacters, !chars.isEmpty else {
            return Unmanaged.passUnretained(event)
        }

        // Handle special keys
        if isDeleteKey(keyCode) {
            if !typedBuffer.isEmpty {
                typedBuffer.removeLast()
            }
            return Unmanaged.passUnretained(event)
        }

        if isResetKey(keyCode) {
            typedBuffer = ""
            return Unmanaged.passUnretained(event)
        }

        // Add to buffer
        typedBuffer.append(chars)
        if typedBuffer.count > maxBufferLength {
            typedBuffer = String(typedBuffer.suffix(maxBufferLength))
        }

        // Try to match snippet
        if let match = await textExpansionEngine.findMatch(in: typedBuffer, triggerChar: chars.last) {
            print("🎯 Match found: \(match.snippet.abbreviation) → \(match.snippet.title)")

            // Clear matched part from buffer
            typedBuffer = ""

            // Trigger expansion
            await textExpansionEngine.expand(match)

            // Optionally suppress trigger character
            // For now, let it through
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
