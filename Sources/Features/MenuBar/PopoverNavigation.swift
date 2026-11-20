import AppKit
import CoreData
import SwiftUI

enum PopoverCategory: String, CaseIterable, Identifiable {
    case recent, images, links, colors, text

    var id: String { rawValue }
    var titleKey: String { "cat_\(rawValue)" }

    var icon: CFIcon.IconType {
        switch self {
        case .recent: return .clock
        case .images: return .image
        case .links: return .link
        case .colors: return .swatch
        case .text: return .text
        }
    }

    var accent: Color {
        switch self {
        case .recent: return BrandPalette.Category.recent
        case .images: return BrandPalette.Category.images
        case .links: return BrandPalette.Category.links
        case .colors: return BrandPalette.Category.colors
        case .text: return BrandPalette.Category.text
        }
    }

    func contains(_ clip: SimpleClipItem) -> Bool {
        switch self {
        case .recent: return true
        case .images: return clip.kind == .image
        case .links: return clip.kind == .url
        case .colors: return clip.kind == .color
        case .text: return clip.kind == .text || clip.kind == .rtf
        }
    }
}

struct SnippetSummary: Equatable {
    let objectID: NSManagedObjectID
    let title: String
    let abbreviation: String
    let content: String
    let useCount: Int32
    let apps: [String]
    let groupID: NSManagedObjectID?
    let groupName: String?

    func searchScore(_ query: String) -> Int? {
        [
            FuzzyMatch.score(query, in: abbreviation),
            FuzzyMatch.score(query, in: title),
            FuzzyMatch.score(query, in: content, allowGaps: false)
        ].compactMap { $0 }.max()
    }
}

struct SnippetGroupSummary: Equatable, Identifiable {
    let objectID: NSManagedObjectID
    let name: String
    var id: NSManagedObjectID { objectID }
}

enum PopoverItem: Identifiable, Equatable {
    case clip(SimpleClipItem, number: Int?)
    case pinned(SimpleClipItem, slot: Int)
    case category(PopoverCategory, count: Int)
    case snippet(SnippetSummary)
    case allSnippets(count: Int)

    var id: String {
        switch self {
        case .clip(let clip, _): return "clip-\(clip.id.uuidString)"
        case .pinned(let clip, _): return "pinned-\(clip.id.uuidString)"
        case .category(let category, _): return "category-\(category.rawValue)"
        case .snippet(let snippet): return "snippet-\(snippet.objectID.uriRepresentation().absoluteString)"
        case .allSnippets: return "all-snippets"
        }
    }

    var drillsIn: Bool {
        switch self {
        case .category, .allSnippets: return true
        default: return false
        }
    }
}

struct PopoverSection: Identifiable, Equatable {
    let id: String
    let title: String
    let trailing: String?
    let items: [PopoverItem]
}

/// What the history popover shows and how the keyboard moves through it.
@MainActor
final class PopoverNavigation: ObservableObject {
    static let shared = PopoverNavigation()
    static let numberedCount = 10
    static let listLimit = 30
    static let topSnippetCount = 3

    weak var clipboardMonitor: ClipboardMonitor?
    var context: NSManagedObjectContext?
    var defaults: UserDefaults = .standard
    var onClose: () -> Void = {}

    @Published var searchText = "" {
        didSet { selectedItemID = nil }
    }
    @Published var drilledCategory: PopoverCategory? {
        didSet { selectedItemID = nil }
    }
    @Published var showsAllSnippets = false {
        didSet { selectedItemID = nil }
    }
    /// The selection follows the item, so pins, deletes and new clips do not move it to another row.
    @Published private var selectedItemID: String?
    /// Enabled snippets of enabled groups, in the editor's group order.
    @Published private(set) var snippets: [SnippetSummary] = []
    @Published private(set) var snippetGroups: [SnippetGroupSummary] = []
    weak var popoverWindow: NSWindow?
    /// Set when the popover opens, from the screen it opens on.
    var maxListHeight: CGFloat = 440

    private var eventMonitor: Any?

    private var isOrganized: Bool { (defaults.string(forKey: "viewMode") ?? "organized") == "organized" }
    private var history: [SimpleClipItem] { clipboardMonitor?.clipHistory ?? [] }

    // MARK: - Content

    var isDrilled: Bool { drilledCategory != nil || showsAllSnippets }

    var sections: [PopoverSection] {
        if !searchText.isEmpty {
            let query = searchText
            let results = Self.ranked(history) { clip in
                [
                    FuzzyMatch.score(query, in: clip.title),
                    FuzzyMatch.score(query, in: clip.content, allowGaps: false),
                    clip.recognizedText.flatMap { FuzzyMatch.score(query, in: $0, allowGaps: false) }
                ].compactMap { $0 }.max()
            }
            let clipSection = numberedSection(id: "results", title: L("search_results"), clips: results)
            let matchingSnippets = Self.ranked(snippets) { $0.searchScore(query) }
            guard !matchingSnippets.isEmpty else { return [clipSection] }
            let snippetSection = PopoverSection(
                id: "snippet-results", title: L("section_snippets"),
                trailing: L("items_count", count: matchingSnippets.count),
                items: matchingSnippets.map { .snippet($0) }
            )
            return results.isEmpty ? [snippetSection] : [clipSection, snippetSection]
        }
        if showsAllSnippets {
            return snippetGroupSections
        }
        if let category = drilledCategory {
            return [numberedSection(id: category.rawValue, title: L(category.titleKey), clips: history.filter(category.contains))]
        }
        guard isOrganized else {
            return [numberedSection(id: "recent", title: L("recent_clips"), clips: history)]
        }

        var sections: [PopoverSection] = []
        let pinned = history.filter(\.isPinned).prefix(9)
        if !pinned.isEmpty {
            sections.append(PopoverSection(
                id: "pinned", title: L("section_pinned"), trailing: nil,
                items: pinned.enumerated().map { .pinned($0.element, slot: $0.offset + 1) }
            ))
        }
        sections.append(PopoverSection(
            id: "categories", title: L("section_categories"), trailing: nil,
            items: PopoverCategory.allCases.map { category in
                .category(category, count: history.filter(category.contains).count)
            }
        ))
        if !snippets.isEmpty {
            let top = snippets
                .sorted { $0.useCount != $1.useCount ? $0.useCount > $1.useCount : $0.title.localizedStandardCompare($1.title) == .orderedAscending }
                .prefix(Self.topSnippetCount)
                .map { PopoverItem.snippet($0) }
            let items = snippets.count > top.count ? top + [.allSnippets(count: snippets.count)] : top
            sections.append(PopoverSection(id: "snippets", title: L("section_snippets"), trailing: nil, items: items))
        }
        return sections
    }

    /// The matching items, best score first; equal scores keep their order (newest clip first).
    static func ranked<Item>(_ items: [Item], by score: (Item) -> Int?) -> [Item] {
        items.enumerated()
            .compactMap { offset, item in score(item).map { (offset, item, $0) } }
            .sorted { $0.2 != $1.2 ? $0.2 > $1.2 : $0.0 < $1.0 }
            .map(\.1)
    }

    private var snippetGroupSections: [PopoverSection] {
        var sections: [PopoverSection] = []
        for snippet in snippets {
            let id = snippet.groupID?.uriRepresentation().absoluteString ?? "no-group"
            if sections.last?.id == id {
                let last = sections.removeLast()
                let items = last.items + [.snippet(snippet)]
                sections.append(PopoverSection(id: id, title: last.title, trailing: L("items_count", count: items.count), items: items))
            } else {
                sections.append(PopoverSection(
                    id: id, title: snippet.groupName ?? L("snippets_no_group"),
                    trailing: L("items_count", count: 1), items: [.snippet(snippet)]
                ))
            }
        }
        return sections
    }

    var items: [PopoverItem] { sections.flatMap(\.items) }

    var selectedID: String? {
        let items = items
        if let selectedItemID, items.contains(where: { $0.id == selectedItemID }) { return selectedItemID }
        return items.first?.id
    }

    private var selectedIndex: Int {
        let items = items
        return items.firstIndex { $0.id == selectedID } ?? 0
    }

    private func numberedSection(id: String, title: String, clips: [SimpleClipItem]) -> PopoverSection {
        let shown = Array(clips.prefix(Self.listLimit))
        return PopoverSection(
            id: id,
            title: title,
            trailing: L("items_count", count: clips.count),
            items: shown.enumerated().map { .clip($0.element, number: $0.offset < Self.numberedCount ? $0.offset + 1 : nil) }
        )
    }

    // MARK: - Lifecycle

    func popoverWillShow() {
        searchText = ""
        goBack()
        selectedItemID = nil
        reloadSnippets()
        guard eventMonitor == nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Only keys typed in the popover; other ClipFlow windows keep theirs.
            guard let window = event.window, MainActor.assumeIsolated({ window === PopoverNavigation.shared.popoverWindow }) else {
                return event
            }
            let key = KeyInput(event)
            let handled = MainActor.assumeIsolated { PopoverNavigation.shared.handle(key) }
            return handled ? nil : event
        }
    }

    func popoverDidClose() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
        eventMonitor = nil
    }

    func reloadSnippets() {
        guard let context else { return }
        let groups = SnippetGroup.ordered(in: context)
        snippetGroups = groups.filter(\.isEnabled).map { SnippetGroupSummary(objectID: $0.objectID, name: $0.name) }
        let ungrouped = Snippet.fetchRequest()
        ungrouped.predicate = NSPredicate(format: "isEnabled == YES AND group == nil")
        let byTitle: (Snippet, Snippet) -> Bool = { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        let ordered = groups.filter(\.isEnabled).flatMap { $0.snippets.filter(\.isEnabled).sorted(by: byTitle) }
            + ((try? context.fetch(ungrouped)) ?? []).sorted(by: byTitle)
        snippets = ordered.map { snippet in
            SnippetSummary(
                objectID: snippet.objectID,
                title: snippet.title,
                abbreviation: snippet.abbreviation,
                content: snippet.content,
                useCount: snippet.useCount,
                apps: snippet.restrictToApps ? (snippet.appRules ?? []).filter { !$0.isDeny }.map(\.appName).sorted() : [],
                groupID: snippet.group?.objectID,
                groupName: snippet.group?.name
            )
        }
    }

    // MARK: - Actions

    func select(_ item: PopoverItem) {
        selectedItemID = item.id
    }

    /// `optionHeld`: the clip pastes the other way from the plain-text preference, once.
    func activate(_ item: PopoverItem, optionHeld: Bool = false) {
        switch item {
        case .clip(let clip, _), .pinned(let clip, _):
            PasteCoordinator.shared.paste(clip, as: optionHeld ? .alternate : .preferred)
        case .category(let category, _):
            showsAllSnippets = false
            drilledCategory = category
        case .allSnippets:
            drilledCategory = nil
            showsAllSnippets = true
        case .snippet(let summary):
            guard let snippet = try? context?.existingObject(with: summary.objectID) as? Snippet else { return }
            PasteCoordinator.shared.insert(snippet)
        }
    }

    /// Back to the top level, with the row that was opened selected.
    func goBack() {
        let openedRow = showsAllSnippets ? "all-snippets" : drilledCategory.map { "category-\($0.rawValue)" }
        drilledCategory = nil
        showsAllSnippets = false
        selectedItemID = openedRow
    }

    /// Saves the clip's text as a snippet in the group, or in a new group when there is none, and opens it in the editor.
    @discardableResult
    func saveAsSnippet(_ clip: SimpleClipItem, in groupID: NSManagedObjectID?) -> Snippet? {
        guard let context, clip.hasPlainText else { return nil }
        let group = groupID.flatMap { try? context.existingObject(with: $0) as? SnippetGroup }
            ?? SnippetGroup.insert(named: L("editor_new_group"), in: context)
        let title = clip.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let snippet = Snippet.insert(
            title: title.isEmpty ? L("editor_new_snippet") : String(title.prefix(60)),
            abbreviation: ".clip", content: clip.content, group: group, in: context
        )
        do {
            try context.save()
        } catch {
            context.rollback()
            Log.storage.error("Saving a clip as a snippet failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
        reloadSnippets()
        SnippetEditorRequests.shared.reveal(snippet.objectID)
        onClose()
        NotificationCenter.default.post(name: NSNotification.Name("OpenSnippetEditor"), object: nil)
        return snippet
    }

    func delete(_ clip: SimpleClipItem) {
        let items = items
        let index = selectedIndex
        if items.indices.contains(index + 1) {
            selectedItemID = items[index + 1].id
        } else if index > 0 {
            selectedItemID = items[index - 1].id
        }
        clipboardMonitor?.delete(clip)
    }

    /// Copies the text in an image clip, read now unless the background pass already did.
    func copyText(from clip: SimpleClipItem) {
        guard let monitor = clipboardMonitor else { return }
        onClose()
        Task {
            var text = clip.recognizedText ?? ""
            if text.isEmpty, let image = monitor.snapshot(for: clip).flatMap({ $0.data(for: .png) ?? $0.data(for: .tiff) }) {
                text = await TextRecognizer.recognize(imageData: image, languages: TextRecognizer.currentLanguages()) ?? ""
                monitor.setRecognizedText(text, forClipID: clip.id)
            }
            guard !text.isEmpty else {
                NSSound.beep()
                return
            }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
    }

    func togglePin(_ clip: SimpleClipItem) {
        clipboardMonitor?.setPinned(clip, !clip.isPinned)
    }

    // MARK: - Keyboard

    struct KeyInput: Sendable {
        let keyCode: UInt16
        let modifiers: Modifiers
        let characters: String?

        struct Modifiers: OptionSet, Sendable {
            let rawValue: Int
            static let command = Modifiers(rawValue: 1)
            static let option = Modifiers(rawValue: 2)
            static let other = Modifiers(rawValue: 4)
        }

        init(keyCode: UInt16, modifiers: Modifiers = [], characters: String? = nil) {
            self.keyCode = keyCode
            self.modifiers = modifiers
            self.characters = characters
        }

        init(_ event: NSEvent) {
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting([.numericPad, .function, .capsLock])
            var modifiers: Modifiers = []
            if flags.contains(.command) { modifiers.insert(.command) }
            if flags.contains(.option) { modifiers.insert(.option) }
            if !flags.subtracting([.command, .option]).isEmpty { modifiers.insert(.other) }
            self.init(keyCode: event.keyCode, modifiers: modifiers, characters: event.charactersIgnoringModifiers)
        }
    }

    private enum KeyCode {
        static let left: UInt16 = 123
        static let right: UInt16 = 124
        static let down: UInt16 = 125
        static let up: UInt16 = 126
        static let returnKey: UInt16 = 36
        static let enter: UInt16 = 76
        static let escape: UInt16 = 53
        static let delete: UInt16 = 51
    }

    func handle(_ key: KeyInput) -> Bool {
        if key.modifiers == .command {
            if let digit = digit(of: key), (1...9).contains(digit) {
                return activatePinned(slot: digit)
            }
            return handleCommand(keyCode: key.keyCode)
        }
        if key.modifiers == .option, key.keyCode == KeyCode.returnKey || key.keyCode == KeyCode.enter {
            if let item = selectedItem { activate(item, optionHeld: true) }
            return true
        }
        if key.modifiers == .option, searchText.isEmpty, let match = numberedItem(for: key) {
            activate(match, optionHeld: true)
            return true
        }
        if key.modifiers == .option, key.keyCode == KeyCode.delete, searchText.isEmpty {
            switch selectedItem {
            case .clip(let clip, _)?, .pinned(let clip, _)?:
                delete(clip)
                return true
            default:
                return false
            }
        }
        guard key.modifiers.isEmpty else { return false }

        let rightToLeft = LanguageManager.shared.layoutDirection == .rightToLeft
        let back = rightToLeft ? KeyCode.right : KeyCode.left
        let forward = rightToLeft ? KeyCode.left : KeyCode.right

        switch key.keyCode {
        case KeyCode.down:
            move(by: 1)
            return true
        case KeyCode.up:
            move(by: -1)
            return true
        case KeyCode.returnKey, KeyCode.enter:
            if let item = selectedItem { activate(item) }
            return true
        case KeyCode.escape:
            if isDrilled, searchText.isEmpty {
                goBack()
            } else {
                PasteCoordinator.shared.returnFocus()
                onClose()
            }
            return true
        case back where searchText.isEmpty && isDrilled:
            goBack()
            return true
        case forward where searchText.isEmpty:
            guard let item = selectedItem, item.drillsIn else { return false }
            activate(item)
            return true
        default:
            break
        }

        guard searchText.isEmpty, let match = numberedItem(for: key) else { return false }
        activate(match)
        return true
    }

    private func numberedItem(for key: KeyInput) -> PopoverItem? {
        guard let digit = digit(of: key) else { return nil }
        let number = digit == 0 ? 10 : digit
        return items.first { item in
            if case .clip(_, let itemNumber) = item { return itemNumber == number }
            return false
        }
    }

    private var selectedItem: PopoverItem? {
        let items = items
        return items.indices.contains(selectedIndex) ? items[selectedIndex] : nil
    }

    private func digit(of key: KeyInput) -> Int? {
        guard let characters = key.characters, characters.count == 1 else { return nil }
        return Int(characters)
    }

    private func move(by delta: Int) {
        let items = items
        guard !items.isEmpty else { return }
        selectedItemID = items[min(max(0, selectedIndex + delta), items.count - 1)].id
    }

    private func activatePinned(slot: Int) -> Bool {
        guard let pinned = history.filter(\.isPinned).dropFirst(slot - 1).first else { return false }
        PasteCoordinator.shared.paste(pinned)
        return true
    }

    /// ⌘E editor, ⌘, preferences, ⌘Q quit, looked up in the current Latin layout.
    private func handleCommand(keyCode: UInt16) -> Bool {
        switch keyCode {
        case SyntheticKeyboard.keyCode(for: "e") ?? 14:
            onClose()
            NotificationCenter.default.post(name: NSNotification.Name("OpenSnippetEditor"), object: nil)
        case SyntheticKeyboard.keyCode(for: ",") ?? 43:
            onClose()
            NotificationCenter.default.post(name: NSNotification.Name("OpenPreferences"), object: nil)
        case SyntheticKeyboard.keyCode(for: "q") ?? 12:
            NSApp.terminate(nil)
        default:
            return false
        }
        return true
    }
}

private struct SelectedClipIDKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

extension EnvironmentValues {
    var selectedPopoverItemID: String? {
        get { self[SelectedClipIDKey.self] }
        set { self[SelectedClipIDKey.self] = newValue }
    }
}
