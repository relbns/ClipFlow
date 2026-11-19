import AppKit
import SwiftUI

/// Hosts the popover's SwiftUI content so the first click acts on a control instead of only
/// activating the window, and keeps the popover sized to the content.
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
        hostingView.onIntrinsicSizeChange = { [weak self, weak hostingView] in
            DispatchQueue.main.async {
                guard let hostingView else { return }
                self?.preferredContentSize = hostingView.fittingSize
            }
        }
        view = hostingView
        preferredContentSize = hostingView.fittingSize
    }
}

private final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    var onIntrinsicSizeChange: (() -> Void)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func invalidateIntrinsicContentSize() {
        super.invalidateIntrinsicContentSize()
        onIntrinsicSizeChange?()
    }
}
