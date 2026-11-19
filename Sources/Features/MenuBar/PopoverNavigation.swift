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
    let apps: [String]
}

enum PopoverItem: Identifiable, Equatable {
    case clip(SimpleClipItem, number: Int?)
    case pinned(SimpleClipItem, slot: Int)
    case category(PopoverCategory, count: Int)
    case snippet(SnippetSummary)

    var id: String {
        switch self {
        case .clip(let clip, _): return "clip-\(clip.id.uuidString)"
        case .pinned(let clip, _): return "pinned-\(clip.id.uuidString)"
        case .category(let category, _): return "category-\(category.rawValue)"
        case .snippet(let snippet): return "snippet-\(snippet.objectID.uriRepresentation().absoluteString)"
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

    weak var clipboardMonitor: ClipboardMonitor?
    var context: NSManagedObjectContext?
    var defaults: UserDefaults = .standard
    var onClose: () -> Void = {}

    @Published var searchText = "" {
        didSet { selectedIndex = 0 }
    }
    @Published var drilledCategory: PopoverCategory? {
        didSet { selectedIndex = 0 }
    }
    @Published private(set) var selectedIndex = 0
    @Published private(set) var snippets: [SnippetSummary] = []

    private var eventMonitor: Any?

    private var isOrganized: Bool { (defaults.string(forKey: "viewMode") ?? "organized") == "organized" }
    private var history: [SimpleClipItem] { clipboardMonitor?.clipHistory ?? [] }

    // MARK: - Content

    var sections: [PopoverSection] {
        if !searchText.isEmpty {
            let results = history.filter {
                $0.content.localizedCaseInsensitiveContains(searchText) || $0.title.localizedCaseInsensitiveContains(searchText)
            }
            return [numberedSection(id: "results", title: L("search_results"), clips: results)]
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
            sections.append(PopoverSection(id: "snippets", title: L("section_snippets"), trailing: nil, items: snippets.map { .snippet($0) }))
        }
        return sections
    }

    var items: [PopoverItem] { sections.flatMap(\.items) }

    var selectedID: String? {
        let items = items
        return items.indices.contains(selectedIndex) ? items[selectedIndex].id : nil
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
        drilledCategory = nil
        selectedIndex = 0
        reloadSnippets()
        guard eventMonitor == nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
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
        let request = Snippet.fetchRequest()
        request.predicate = NSPredicate(format: "isEnabled == YES")
        request.sortDescriptors = [
            NSSortDescriptor(key: "useCount", ascending: false),
            NSSortDescriptor(key: "title", ascending: true)
        ]
        request.fetchLimit = 3
        snippets = ((try? context.fetch(request)) ?? []).map { snippet in
            SnippetSummary(
                objectID: snippet.objectID,
                title: snippet.title,
                abbreviation: snippet.abbreviation,
                apps: snippet.restrictToApps ? (snippet.appRules ?? []).filter { !$0.isDeny }.map(\.appName).sorted() : []
            )
        }
    }

    // MARK: - Actions

    func select(_ item: PopoverItem) {
        if let index = items.firstIndex(of: item) { selectedIndex = index }
    }

    func activate(_ item: PopoverItem) {
        switch item {
        case .clip(let clip, _), .pinned(let clip, _):
            PasteCoordinator.shared.paste(clip)
        case .category(let category, _):
            drilledCategory = category
        case .snippet(let summary):
            guard let snippet = try? context?.existingObject(with: summary.objectID) as? Snippet else { return }
            PasteCoordinator.shared.insert(snippet)
        }
    }

    func goBack() {
        drilledCategory = nil
    }

    func delete(_ clip: SimpleClipItem) {
        clipboardMonitor?.delete(clip)
        selectedIndex = min(selectedIndex, max(0, items.count - 1))
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
        if key.modifiers == .option, key.keyCode == KeyCode.delete {
            guard case .clip(let clip, _)? = selectedItem else { return false }
            delete(clip)
            return true
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
            if drilledCategory != nil, searchText.isEmpty { goBack() } else { onClose() }
            return true
        case back where searchText.isEmpty && drilledCategory != nil:
            goBack()
            return true
        case forward where searchText.isEmpty:
            guard let item = selectedItem, case .category = item else { return false }
            activate(item)
            return true
        default:
            break
        }

        guard searchText.isEmpty, let digit = digit(of: key) else { return false }
        let number = digit == 0 ? 10 : digit
        let match = items.first { item in
            if case .clip(_, let itemNumber) = item { return itemNumber == number }
            return false
        }
        if let match { activate(match) }
        return true
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
        let count = items.count
        guard count > 0 else { return }
        selectedIndex = min(max(0, selectedIndex + delta), count - 1)
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
