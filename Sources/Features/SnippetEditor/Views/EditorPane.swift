import AppKit
import Combine
import SwiftUI

// MARK: - Center

struct EditorPane: View {
    @ObservedObject var snippet: Snippet
    @ObservedObject var model: SnippetEditorModel
    @Environment(\.cfTheme) private var theme
    @Environment(\.locale) private var locale

    private let variables = ["{date}", "{time}", "{clipboard}", "{cursor}", "{prompt:Name}"]
    private let triggers = ["delimiter", "space", "tab", "enter", "any"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if let message = bannerMessage {
                banner(message)
            }
            triggerCard
            variableBar
            SnippetTextEditor(text: binding(\.content), insertions: model.insertions)
                .background(RoundedRectangle(cornerRadius: 8).fill(theme.surfaceDeep))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(theme.stroke, lineWidth: 1))
                .padding(EdgeInsets(top: 12, leading: 22, bottom: 12, trailing: 22))
            statusBar
        }
    }

    private func binding<Value>(_ keyPath: ReferenceWritableKeyPath<Snippet, Value>) -> Binding<Value> {
        Binding(get: { snippet[keyPath: keyPath] }, set: { snippet[keyPath: keyPath] = $0; model.edited() })
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(L("editor_title"), text: binding(\.title))
                .textFieldStyle(.plain)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(theme.textStrong)
            HStack(spacing: 10) {
                HStack(spacing: 4) {
                    CFIcon(type: .folder, size: 12, stroke: 1.6)
                    Text(snippet.group?.name ?? "")
                }
                Bullet()
                Text(L("editor_usage", count: Int(snippet.useCount)) + " · " + L("editor_saved_time", savedTime))
                Bullet()
                Text(L("editor_updated", snippet.updatedAt.formatted(.relative(presentation: .named).locale(locale))))
            }
            .font(.system(size: 12))
            .foregroundColor(theme.textSubtle)
            .lineLimit(1)
        }
        .padding(EdgeInsets(top: 14, leading: 22, bottom: 10, trailing: 22))
    }

    private var savedTime: String {
        let minutes = snippet.minutesSaved
        if minutes < 1 { return L("editor_under_a_minute") }
        if minutes < 90 { return L("editor_minutes", Int(minutes.rounded())) }
        return L("editor_hours", Int((minutes / 60).rounded()))
    }

    // MARK: Banner

    private var bannerMessage: (text: String, conflict: Snippet?)? {
        if let error = model.abbreviationDraftError { return (error, nil) }
        if case .invalid(let error) = model.saveState { return (error, nil) }
        if let other = model.conflict(for: snippet) { return (L("editor_conflict", other.title), other) }
        return nil
    }

    private func banner(_ message: (text: String, conflict: Snippet?)) -> some View {
        HStack(spacing: 10) {
            CFIcon(type: .info, size: 14, stroke: 1.8).foregroundColor(BrandPalette.warningIcon)
            Text(message.text).font(.system(size: 12)).foregroundColor(theme.text).frame(maxWidth: .infinity, alignment: .leading)
            if let other = message.conflict {
                CFToolbarBtn(label: L("editor_resolve")) { model.select(other) }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8).fill(BrandPalette.warning.mixed(20)))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(BrandPalette.warning.mixed(40), lineWidth: 1))
        .padding(EdgeInsets(top: 0, leading: 22, bottom: 10, trailing: 22))
    }

    // MARK: Trigger card

    private var triggerCard: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                CardLabel(text: L("editor_abbreviation"))
                HStack(spacing: 8) {
                    TextField(".sig", text: Binding(get: { model.abbreviationDraft }, set: { model.abbreviationEdited($0) }))
                        .accessibilityLabel(L("editor_abbreviation"))
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(theme.textStrong)
                        .frame(maxWidth: 160)
                        .environment(\.layoutDirection, .leftToRight)
                    Text(L("abbr_rule_hint")).font(.system(size: 11)).foregroundColor(theme.textSubtle).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                CardLabel(text: L("editor_trigger"))
                Picker(L("editor_trigger"), selection: binding(\.expandTrigger)) {
                    ForEach(triggers, id: \.self) { Text(L("trigger_\($0)_long")).tag($0) }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 190)
            }

            VStack(alignment: .leading, spacing: 4) {
                CardLabel(text: L("editor_status"))
                HStack(spacing: 6) {
                    CFToggle(isOn: binding(\.isEnabled)).accessibilityLabel(L("editor_enabled"))
                    Text(snippet.isEnabled ? L("editor_enabled") : L("editor_disabled")).font(.system(size: 12)).foregroundColor(theme.textMid)
                }
            }
        }
        .padding(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
        .background(RoundedRectangle(cornerRadius: 8).fill(theme.fillSoft))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(theme.stroke, lineWidth: 1))
        .padding(.horizontal, 22)
    }

    // MARK: Variables

    private var variableBar: some View {
        HStack(spacing: 6) {
            Text(L("editor_insert")).font(.system(size: 12)).foregroundColor(theme.textSubtle).fixedSize().padding(.trailing, 4)
            ForEach(variables, id: \.self) { variable in
                Button { model.insertions.send(variable) } label: { CFVarChip(variable) }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L("editor_insert_variable", variable))
            }
            Spacer(minLength: 8)
            ViewThatFits(in: .horizontal) {
                Text(L("editor_date_format_hint")).font(.system(size: 11)).foregroundColor(theme.textFaint).fixedSize()
                Color.clear.frame(width: 0, height: 0)
            }
        }
        .padding(EdgeInsets(top: 14, leading: 22, bottom: 0, trailing: 22))
    }

    // MARK: Status bar

    private var statusBar: some View {
        let lines = snippet.content.isEmpty ? 0 : snippet.content.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).count
        let variableCount = SnippetTextEditor.tokenPattern.numberOfMatches(in: snippet.content, range: NSRange(snippet.content.startIndex..., in: snippet.content))
        return HStack(spacing: 14) {
            Text(L("editor_plain_text"))
            Bullet()
            Text("\(L("editor_lines", count: lines)) · \(L("editor_chars", count: snippet.content.count))")
            Bullet()
            Text(L("editor_variables", count: variableCount))
            Spacer()
            HStack(spacing: 4) {
                Circle().fill(saveColor).frame(width: 6, height: 6)
                Text(saveLabel)
            }
            .animation(.easeInOut(duration: 0.4), value: model.saveState)
        }
        .font(.system(size: 11))
        .foregroundColor(theme.textSubtle)
        .padding(.horizontal, 22)
        .frame(height: 28)
        .overlay(Rectangle().fill(theme.strokeSoft).frame(height: 1), alignment: .top)
    }

    private var saveColor: Color {
        if model.abbreviationDraftError != nil { return BrandPalette.danger }
        switch model.saveState {
        case .saved: return BrandPalette.success
        case .saving: return BrandPalette.warning
        case .invalid: return BrandPalette.danger
        }
    }

    private var saveLabel: String {
        if model.abbreviationDraftError != nil { return L("editor_not_saved") }
        switch model.saveState {
        case .saved: return L("editor_saved")
        case .saving: return L("editor_saving")
        case .invalid: return L("editor_not_saved")
        }
    }
}

private struct CardLabel: View {
    let text: String
    @Environment(\.cfTheme) private var theme

    var body: some View {
        Text(text).font(.system(size: 11)).foregroundColor(theme.textSubtle)
    }
}

struct Bullet: View {
    @Environment(\.cfTheme) private var theme

    var body: some View {
        Circle().fill(theme.textBullet).frame(width: 3, height: 3)
    }
}

// MARK: - Inspector

struct EditorInspector: View {
    @ObservedObject var snippet: Snippet
    @ObservedObject var model: SnippetEditorModel
    @Environment(\.cfTheme) private var theme
    @Environment(\.locale) private var locale

    private let triggers = ["delimiter", "space", "tab", "enter", "any"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("inspector_title")).font(.system(size: 13, weight: .semibold)).foregroundColor(theme.textStrong)
                    Text(L("inspector_subtitle")).font(.system(size: 11)).foregroundColor(theme.textSubtle)
                }
                .padding(EdgeInsets(top: 12, leading: 16, bottom: 6, trailing: 16))

                InspectorBlock(title: L("inspector_trigger")) {
                    InspectorField(label: L("inspector_fires_on"), hint: L("inspector_fires_on_hint")) {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 4) {
                            ForEach(triggers, id: \.self) { trigger in
                                let on = snippet.expandTrigger == trigger
                                Button {
                                    snippet.expandTrigger = trigger
                                    model.edited()
                                } label: {
                                    Text(L("trigger_\(trigger)"))
                                        .font(.system(size: 11))
                                        .foregroundColor(on ? theme.textStrong : theme.textSubtle)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 4)
                                        .background(RoundedRectangle(cornerRadius: 4).fill(on ? theme.fill2 : .clear))
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(on ? .isSelected : [])
                            }
                        }
                        .padding(2)
                        .background(RoundedRectangle(cornerRadius: 6).fill(theme.inputBg))
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(theme.stroke, lineWidth: 1))
                    }
                    optionRow(L("editor_case_sensitive"), isOn: Binding(get: { snippet.caseSensitive }, set: { snippet.caseSensitive = $0; model.edited() }))
                    optionRow(L("editor_play_sound"), isOn: Binding(get: { snippet.playSound }, set: { snippet.playSound = $0; model.edited() }))
                }

                InspectorBlock(title: L("inspector_app_rules")) {
                    optionRow(L("editor_restrict_apps"), isOn: Binding(get: { snippet.restrictToApps }, set: { snippet.restrictToApps = $0; model.edited() }))
                    VStack(spacing: 6) {
                        ForEach(Array(snippet.appRules ?? []).sorted { $0.appName < $1.appName }, id: \.objectID) { rule in
                            appRuleRow(rule)
                        }
                        Button { model.addAppRule(to: snippet) } label: {
                            HStack(spacing: 6) {
                                CFIcon(type: .plus, size: 11, stroke: 1.8)
                                Text(L("add_app")).font(.system(size: 12))
                                Spacer()
                            }
                            .foregroundColor(theme.textMuted)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(theme.fill3, style: StrokeStyle(lineWidth: 1, dash: [3, 2])))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    Text(L(snippet.restrictToApps ? "inspector_rules_restricted" : "inspector_rules_open"))
                        .font(.system(size: 11))
                        .foregroundColor(theme.textFaint)
                        .padding(.top, 6)
                }

                InspectorBlock(title: L("editor_section_statistics")) {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                        stat(value: "\(snippet.useCount)", label: L("stat_expansions"))
                        stat(value: snippet.minutesSaved < 1 ? "–" : L("editor_minutes", Int(snippet.minutesSaved.rounded())), label: L("stat_time_saved"))
                        stat(value: "\(snippet.charactersSaved)", label: L("stat_chars_saved"))
                        stat(value: snippet.lastUsed?.formatted(.dateTime.month(.abbreviated).day().locale(locale)) ?? "–", label: L("stat_last_used"))
                    }
                }
            }
        }
        .background(theme.surfaceAlt)
        .overlay(Rectangle().fill(theme.strokeSoft).frame(width: 1), alignment: .leading)
    }

    private func optionRow(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title).font(.system(size: 12)).foregroundColor(theme.textMid)
            Spacer()
            CFToggle(isOn: isOn).accessibilityLabel(title)
        }
        .padding(.bottom, 8)
    }

    private func appRuleRow(_ rule: AppRule) -> some View {
        HStack(spacing: 8) {
            appIcon(rule.bundleIdentifier).frame(width: 16, height: 16)
            Text(rule.appName).font(.system(size: 12)).foregroundColor(theme.text).lineLimit(1)
            Spacer()
            Button { model.toggleDeny(rule) } label: {
                Text(rule.isDeny ? L("rule_deny") : L("rule_allow"))
                    .font(.system(size: 11))
                    .foregroundColor(rule.isDeny ? theme.textFaint : BrandPalette.successText)
            }
            .buttonStyle(.plain)
            .help(L("rule_toggle_help"))
            Button { model.remove(rule) } label: {
                Text("×").font(.system(size: 13, weight: .medium)).foregroundColor(theme.textFaint)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L("rule_remove", rule.appName))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 6).fill(theme.fillSoft))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(theme.strokeSoft, lineWidth: 1))
    }

    @ViewBuilder
    private func appIcon(_ bundleID: String) -> some View {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable()
        } else {
            RoundedRectangle(cornerRadius: 4).fill(theme.fill1)
        }
    }

    private func stat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(.system(size: 14, weight: .semibold)).foregroundColor(theme.textStrong).lineLimit(1)
            Text(label).font(.system(size: 10.5)).foregroundColor(theme.textSubtle).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 6).fill(theme.fillSoft))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(theme.strokeSoft, lineWidth: 1))
    }
}

private struct InspectorBlock<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    @Environment(\.cfTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(0.06 * 10.5)
                .textCase(.uppercase)
                .foregroundColor(theme.textSubtle)
                .padding(.bottom, 10)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
        .overlay(Rectangle().fill(theme.strokeSoft).frame(height: 1), alignment: .top)
    }
}

private struct InspectorField<Content: View>: View {
    let label: String
    var hint: String?
    @ViewBuilder let content: () -> Content
    @Environment(\.cfTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 11.5)).foregroundColor(theme.textMuted)
            content()
            if let hint {
                Text(hint).font(.system(size: 11)).foregroundColor(theme.textFaint).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.bottom, 12)
    }
}

// MARK: - Text editor

/// An NSTextView that shows `{variables}` as chips and inserts a clicked variable at the caret.
struct SnippetTextEditor: NSViewRepresentable {
    /// A variable, not one written with doubled braces (`{{date}}` is the literal text `{date}`).
    static let tokenPattern = try! NSRegularExpression(pattern: #"(?<!\{)\{[^{}\n]+\}(?!\})"#)

    @Binding var text: String
    let insertions: PassthroughSubject<String, Never>
    @Environment(\.cfTheme) private var theme

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }
        textView.delegate = context.coordinator
        textView.drawsBackground = false
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.textContainerInset = NSSize(width: 12, height: 14)
        textView.setAccessibilityLabel(L("editor_content_label"))
        textView.string = text
        context.coordinator.textView = textView
        context.coordinator.applyStyle(theme: theme)
        context.coordinator.subscription = insertions.sink { [weak coordinator = context.coordinator] variable in
            coordinator?.insert(variable)
        }
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.text = $text
        guard let textView = coordinator.textView else { return }
        if textView.string != text {
            textView.string = text
            coordinator.applyStyle(theme: theme)
        } else if coordinator.colorScheme != theme.colorScheme {
            coordinator.applyStyle(theme: theme)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        weak var textView: NSTextView?
        var subscription: AnyCancellable?
        private(set) var colorScheme: ColorScheme?
        private var theme = CFTheme.light

        init(text: Binding<String>) {
            self.text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            text.wrappedValue = textView.string
            highlightTokens()
        }

        func insert(_ variable: String) {
            guard let textView else { return }
            textView.window?.makeFirstResponder(textView)
            textView.insertText(variable, replacementRange: textView.selectedRange())
        }

        func applyStyle(theme: CFTheme) {
            guard let textView else { return }
            self.theme = theme
            colorScheme = theme.colorScheme
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineHeightMultiple = 1.3
            textView.font = NSFont.systemFont(ofSize: 14)
            textView.textColor = NSColor(theme.text)
            textView.insertionPointColor = NSColor(theme.caret)
            textView.defaultParagraphStyle = paragraph
            textView.typingAttributes = [.font: NSFont.systemFont(ofSize: 14), .foregroundColor: NSColor(theme.text), .paragraphStyle: paragraph]
            textView.textStorage?.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: textView.string.utf16.count))
            highlightTokens()
        }

        private func highlightTokens() {
            guard let textView, let layoutManager = textView.layoutManager else { return }
            let whole = NSRange(location: 0, length: textView.string.utf16.count)
            layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: whole)
            layoutManager.removeTemporaryAttribute(.foregroundColor, forCharacterRange: whole)
            for match in SnippetTextEditor.tokenPattern.matches(in: textView.string, range: whole) {
                layoutManager.addTemporaryAttributes([
                    .backgroundColor: NSColor(BrandPalette.varChip.mixed(30)),
                    .foregroundColor: NSColor(theme.varChipText)
                ], forCharacterRange: match.range)
            }
        }
    }
}
