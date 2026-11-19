import AppKit
import SwiftUI

/// Hosts the popover content in a view that takes the first click, so a control reacts even when the
/// popover opened from a global hotkey and ClipFlow was not active. The SwiftUI content reports its
/// size, and `onSize` applies it to the popover.
final class PopoverContentController<Content: View>: NSViewController {
    private let rootView: Content

    init(rootView: Content) {
        self.rootView = rootView
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        let hostingView = FirstClickHostingView(rootView: rootView)
        hostingView.sizingOptions = []
        view = hostingView
    }
}

private final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

struct PopoverSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}
