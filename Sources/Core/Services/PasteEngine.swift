import AppKit

/// Pasteboard change counts written by ClipFlow itself, so history does not record them.
@MainActor
final class OwnPasteboardWrites {
    static let shared = OwnPasteboardWrites()
    private var counts: [Int] = []

    func record(_ changeCount: Int) {
        counts.append(changeCount)
        if counts.count > 32 { counts.removeFirst(counts.count - 32) }
    }

    func contains(_ changeCount: Int) -> Bool {
        counts.contains(changeCount)
    }
}

@MainActor
final class PasteEngine {
    static let shared = PasteEngine()

    private let pasteboard = NSPasteboard.general
    private let restoreDelay: TimeInterval = 0.5

    private struct PendingRestore {
        let original: PasteboardSnapshot?
        let temporaryChangeCount: Int
        let work: DispatchWorkItem
    }
    private var pendingRestore: PendingRestore?

    /// Runs before ClipFlow writes to the pasteboard, so a copy made a moment earlier still reaches history.
    var beforeWrite: () -> Void = {}

    /// Types text into the frontmost app through the pasteboard and puts the user's clipboard back afterwards.
    func insert(_ rendered: RenderedSnippet, replacingTyped deleteCount: Int) {
        SyntheticKeyboard.deleteBackward(count: deleteCount)

        let original: PasteboardSnapshot?
        if let pending = pendingRestore, pasteboard.changeCount == pending.temporaryChangeCount {
            pending.work.cancel()
            original = pending.original
        } else {
            pendingRestore?.work.cancel()
            original = PasteboardSnapshot.capture(from: pasteboard, maxBytes: .max)
        }
        let ourCount = write(.text(rendered.text, transient: true))

        SyntheticKeyboard.paste()
        SyntheticKeyboard.moveLeft(count: rendered.cursorOffsetFromEnd)

        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.pendingRestore = nil
                guard self.pasteboard.changeCount == ourCount, let original else { return }
                self.write(original)
            }
        }
        pendingRestore = PendingRestore(original: original, temporaryChangeCount: ourCount, work: work)
        DispatchQueue.main.asyncAfter(deadline: .now() + restoreDelay, execute: work)
    }

    /// Puts a history clip on the pasteboard, where it stays, and pastes it into `target`.
    func paste(_ snapshot: PasteboardSnapshot, into target: NSRunningApplication?) async {
        write(snapshot)
        await activate(target)
        SyntheticKeyboard.paste()
    }

    /// Inserts rendered snippet text into `target` without touching the user's clipboard for long.
    func insert(_ rendered: RenderedSnippet, into target: NSRunningApplication?) async {
        await activate(target)
        insert(rendered, replacingTyped: 0)
    }

    @discardableResult
    private func write(_ snapshot: PasteboardSnapshot) -> Int {
        beforeWrite()
        let count = snapshot.write(to: pasteboard)
        OwnPasteboardWrites.shared.record(count)
        return count
    }

    func activate(_ target: NSRunningApplication?) async {
        guard let target, !target.isTerminated else { return }
        if NSWorkspace.shared.frontmostApplication?.processIdentifier != target.processIdentifier {
            target.activate()
            for _ in 0..<50 {
                if NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processIdentifier { break }
                try? await Task.sleep(nanoseconds: 20_000_000)
            }
        }
        try? await Task.sleep(nanoseconds: 60_000_000)
    }
}
