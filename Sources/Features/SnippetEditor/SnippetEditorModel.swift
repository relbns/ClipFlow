import AppKit
import CoreData
import SwiftUI

/// State and actions of the Snippet Editor. Edits write straight to the managed objects and are
/// saved 400ms after the last change, once the abbreviation is valid.
@MainActor
final class SnippetEditorModel: ObservableObject {
    enum Library: String { case favorites, recent }

    enum SaveState: Equatable {
        case saved
        case saving
        case invalid(String)
    }

    let context: NSManagedObjectContext
    @Published var filterText = ""
    @Published var library: Library?
    @Published private(set) var selectedID: NSManagedObjectID?
    @Published var collapsedGroups: Set<NSManagedObjectID> = []
    @Published private(set) var saveState: SaveState = .saved
    /// A variable chip the user clicked; the text view inserts it at the caret.
    @Published var pendingInsertion: String?
    @Published var confirmingDelete: Snippet?
    @Published var confirmingGroupDelete: SnippetGroup?
    @Published var renamingGroupID: NSManagedObjectID?

    private var saveWork: DispatchWorkItem?

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    // MARK: - Reading

    var selected: Snippet? {
        guard let selectedID, let snippet = try? context.existingObject(with: selectedID) as? Snippet, !snippet.isDeleted else { return nil }
        return snippet
    }

    var groups: [SnippetGroup] {
        let request = SnippetGroup.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true), NSSortDescriptor(key: "createdAt", ascending: true)]
        return (try? context.fetch(request)) ?? []
    }

    func snippets(in group: SnippetGroup) -> [Snippet] {
        group.snippets.filter(matchesFilter).sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    func snippets(in library: Library) -> [Snippet] {
        let request = Snippet.fetchRequest()
        switch library {
        case .favorites:
            request.predicate = NSPredicate(format: "isFavorite == YES")
            request.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        case .recent:
            request.predicate = NSPredicate(format: "lastUsed != nil")
            request.sortDescriptors = [NSSortDescriptor(key: "lastUsed", ascending: false)]
            request.fetchLimit = 30
        }
        return ((try? context.fetch(request)) ?? []).filter(matchesFilter)
    }

    var totalCount: Int { (try? context.count(for: Snippet.fetchRequest())) ?? 0 }

    private func matchesFilter(_ snippet: Snippet) -> Bool {
        let query = filterText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        return snippet.title.localizedCaseInsensitiveContains(query)
            || snippet.abbreviation.localizedCaseInsensitiveContains(query)
            || snippet.content.localizedCaseInsensitiveContains(query)
    }

    // MARK: - Selection

    func select(_ snippet: Snippet?) {
        if case .invalid = saveState, let current = selected, current.objectID != snippet?.objectID {
            context.refresh(current, mergeChanges: false)
            saveState = .saved
        }
        selectedID = snippet?.objectID
    }

    func selectFirstIfNeeded() {
        guard selected == nil else { return }
        select(groups.lazy.flatMap { self.snippets(in: $0) }.first)
    }

    // MARK: - Editing

    /// Call after every edit to the selected snippet.
    func edited() {
        saveState = .saving
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.commit() }
        }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    func commit() {
        if let snippet = selected, let error = Self.abbreviationError(snippet.abbreviation) {
            saveState = .invalid(error)
            return
        }
        selected?.updatedAt = Date()
        save()
        saveState = .saved
    }

    /// The other enabled snippet with the same abbreviation, if any; only one of them would fire.
    func conflict(for snippet: Snippet) -> Snippet? {
        let request = Snippet.fetchRequest()
        request.predicate = NSPredicate(format: "abbreviation ==[c] %@ AND isEnabled == YES AND self != %@", snippet.abbreviation, snippet)
        request.fetchLimit = 1
        return snippet.isEnabled ? (try? context.fetch(request))?.first : nil
    }

    @MainActor
    static func abbreviationError(_ abbreviation: String) -> String? {
        guard let first = abbreviation.first else { return L("abbr_error_empty") }
        if !".;/".contains(first) { return L("abbr_error_prefix") }
        if abbreviation.contains(where: \.isWhitespace) { return L("abbr_error_spaces") }
        let allowed = abbreviation.unicodeScalars.allSatisfy { scalar in
            CharacterSet.letters.contains(scalar) || CharacterSet.decimalDigits.contains(scalar) || "._-/;".unicodeScalars.contains(scalar)
        }
        return allowed ? nil : L("abbr_error_characters")
    }

    // MARK: - Actions

    func newSnippet() {
        let group = selected?.group ?? groups.first ?? newGroup(select: false)
        let snippet = Snippet(context: context)
        snippet.id = UUID()
        snippet.title = L("editor_new_snippet")
        snippet.abbreviation = uniqueAbbreviation(".new")
        snippet.content = ""
        snippet.isEnabled = true
        snippet.createdAt = Date()
        snippet.updatedAt = Date()
        snippet.expandTrigger = UserDefaults.standard.string(forKey: "expandAfter") ?? ExpandTrigger.delimiter.rawValue
        snippet.group = group
        collapsedGroups.remove(group.objectID)
        save()
        select(snippet)
    }

    func duplicate(_ snippet: Snippet) {
        let copy = Snippet(context: context)
        copy.id = UUID()
        copy.title = snippet.title
        copy.abbreviation = uniqueAbbreviation(snippet.abbreviation)
        copy.content = snippet.content
        copy.isEnabled = snippet.isEnabled
        copy.createdAt = Date()
        copy.updatedAt = Date()
        copy.expandTrigger = snippet.expandTrigger
        copy.caseSensitive = snippet.caseSensitive
        copy.playSound = snippet.playSound
        copy.restrictToApps = snippet.restrictToApps
        copy.group = snippet.group
        for rule in snippet.appRules ?? [] {
            AppRule.create(in: context, bundleID: rule.bundleIdentifier, appName: rule.appName, isDeny: rule.isDeny).snippet = copy
        }
        save()
        select(copy)
    }

    func delete(_ snippet: Snippet) {
        if selectedID == snippet.objectID { selectedID = nil }
        context.delete(snippet)
        save()
        selectFirstIfNeeded()
    }

    @discardableResult
    func newGroup(select: Bool = true) -> SnippetGroup {
        let group = SnippetGroup(context: context)
        group.id = UUID()
        group.name = L("editor_new_group")
        group.isEnabled = true
        group.createdAt = Date()
        group.sortOrder = Int32((groups.map(\.sortOrder).max() ?? 0) + 1)
        save()
        if select { renamingGroupID = group.objectID }
        return group
    }

    func rename(_ group: SnippetGroup, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { group.name = trimmed }
        renamingGroupID = nil
        save()
    }

    func delete(_ group: SnippetGroup) {
        if let selected, selected.group == group { selectedID = nil }
        context.delete(group)
        save()
        selectFirstIfNeeded()
    }

    func toggleEnabled(_ group: SnippetGroup) {
        group.isEnabled.toggle()
        save()
    }

    func toggleFavorite(_ snippet: Snippet) {
        snippet.isFavorite.toggle()
        save()
    }

    func toggleCollapsed(_ group: SnippetGroup) {
        if collapsedGroups.contains(group.objectID) {
            collapsedGroups.remove(group.objectID)
        } else {
            collapsedGroups.insert(group.objectID)
        }
    }

    func addAppRule(to snippet: Snippet) {
        AppExclusions.pickApplication { [weak self] bundleID, name in
            MainActor.assumeIsolated {
                guard let self, !(snippet.appRules ?? []).contains(where: { $0.bundleIdentifier == bundleID }) else { return }
                AppRule.create(in: self.context, bundleID: bundleID, appName: name).snippet = snippet
                self.save()
            }
        }
    }

    func toggleDeny(_ rule: AppRule) {
        rule.isDeny.toggle()
        save()
    }

    func remove(_ rule: AppRule) {
        context.delete(rule)
        save()
    }

    func save() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            Log.ui.error("Could not save snippets: \(error.localizedDescription, privacy: .public)")
            saveState = .invalid(error.localizedDescription)
        }
        objectWillChange.send()
    }

    private func uniqueAbbreviation(_ base: String) -> String {
        let request = Snippet.fetchRequest()
        let existing = Set(((try? context.fetch(request)) ?? []).map { $0.abbreviation.lowercased() })
        guard existing.contains(base.lowercased()) else { return base }
        var number = 2
        while existing.contains("\(base)\(number)".lowercased()) { number += 1 }
        return "\(base)\(number)"
    }
}

extension Snippet {
    /// Rough time saved: characters not typed, at 200 characters a minute.
    var minutesSaved: Double {
        let typed = Double(max(0, SnippetTemplate.render(content, context: TemplateContext(now: Date(), timeZone: .current, locale: .current, clipboard: "")).text.count - abbreviation.count))
        return Double(useCount) * typed / 200
    }

    var charactersSaved: Int {
        Int(useCount) * max(0, content.count - abbreviation.count)
    }
}
