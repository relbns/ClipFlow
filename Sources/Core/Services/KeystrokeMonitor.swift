import Cocoa

enum TypingEvent {
    case characters(String)
    case deleteBackward
    case reset
}

/// A listen-only event tap: it sees keystrokes and clicks but never delays or changes them.
@MainActor
final class KeystrokeMonitor {
    private(set) var isMonitoring = false
    var onEvent: (TypingEvent) -> Void = { _ in }

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private enum KeyCode {
        static let delete: Int64 = 51
        static let resetting: Set<Int64> = [53, 115, 116, 117, 119, 121, 123, 124, 125, 126]
    }

    func start() -> Bool {
        guard !isMonitoring else { return true }

        let mask: CGEventMask = [CGEventType.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]
            .reduce(0) { $0 | (1 << $1.rawValue) }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: keystrokeTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            Log.expansion.error("Could not create the keyboard event tap")
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        runLoopSource = source
        isMonitoring = true
        Log.expansion.info("Keyboard monitoring started")
        return true
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        isMonitoring = false
        Log.expansion.info("Keyboard monitoring stopped")
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
                Log.expansion.notice("Event tap was disabled by the system and has been re-enabled")
            }
            onEvent(.reset)
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            onEvent(.reset)
        case .keyDown:
            handleKeyDown(event)
        default:
            break
        }
    }

    private func handleKeyDown(_ event: CGEvent) {
        guard !SyntheticKeyboard.isSynthetic(event) else { return }

        if !event.flags.isDisjoint(with: [.maskCommand, .maskControl]) {
            onEvent(.reset)
            return
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        if keyCode == KeyCode.delete {
            onEvent(.deleteBackward)
        } else if KeyCode.resetting.contains(keyCode) {
            onEvent(.reset)
        } else if let characters = event.typedCharacters {
            let isFunctionKey = characters.unicodeScalars.contains { $0.properties.generalCategory == .privateUse }
            onEvent(isFunctionKey ? .reset : .characters(characters))
        }
    }
}

private func keystrokeTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    if let refcon {
        let monitor = Unmanaged<KeystrokeMonitor>.fromOpaque(refcon).takeUnretainedValue()
        MainActor.assumeIsolated {
            monitor.handle(type: type, event: event)
        }
    }
    return Unmanaged.passUnretained(event)
}

extension CGEvent {
    var typedCharacters: String? {
        var length = 0
        var buffer = [UniChar](repeating: 0, count: 8)
        keyboardGetUnicodeString(maxStringLength: buffer.count, actualStringLength: &length, unicodeString: &buffer)
        guard length > 0 else { return nil }
        let characters = String(utf16CodeUnits: buffer, count: length)
        return characters.unicodeScalars.allSatisfy({ $0.properties.generalCategory == .control && $0 != "\r" && $0 != "\t" })
            ? nil
            : characters
    }
}
