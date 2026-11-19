import AppKit

@MainActor
enum SnippetRenderer {
    /// Renders a snippet for insertion, asking for prompt values first. Returns nil when the user cancels.
    static func render(_ content: String, returningFocusTo target: NSRunningApplication?) async -> RenderedSnippet? {
        let clipboard = currentClipboardText()
        let prompts = SnippetTemplate.prompts(in: content)
        var values: [String: String] = [:]

        if !prompts.isEmpty {
            let answers = PromptDialog.ask(prompts)
            await PasteEngine.shared.activate(target)
            guard let answers else { return nil }
            values = answers
        }
        return SnippetTemplate.render(content, context: makeContext(clipboard: clipboard, promptValues: values))
    }

    static func renderWithoutPrompts(_ content: String) -> RenderedSnippet {
        SnippetTemplate.render(content, context: makeContext(clipboard: currentClipboardText(), promptValues: [:]))
    }

    private static func currentClipboardText() -> String {
        NSPasteboard.general.string(forType: .string) ?? ""
    }

    private static func makeContext(clipboard: String, promptValues: [String: String]) -> TemplateContext {
        TemplateContext(
            now: Date(),
            timeZone: TimeZone.current,
            locale: Locale.current,
            clipboard: clipboard,
            promptValues: promptValues
        )
    }
}

@MainActor
enum PromptDialog {
    static func ask(_ prompts: [SnippetPrompt]) -> [String: String]? {
        let alert = NSAlert()
        alert.messageText = L("fill_in_snippet")
        alert.addButton(withTitle: L("insert"))
        alert.addButton(withTitle: L("cancel"))

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6

        var fields: [(String, NSTextField)] = []
        for prompt in prompts {
            let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
            field.translatesAutoresizingMaskIntoConstraints = false
            field.widthAnchor.constraint(equalToConstant: 280).isActive = true
            stack.addArrangedSubview(NSTextField(labelWithString: prompt.label))
            stack.addArrangedSubview(field)
            fields.append((prompt.key, field))
        }
        stack.layoutSubtreeIfNeeded()
        stack.frame.size = stack.fittingSize
        alert.accessoryView = stack
        alert.window.initialFirstResponder = fields.first?.1

        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return Dictionary(uniqueKeysWithValues: fields.map { ($0.0, $0.1.stringValue) })
    }
}
