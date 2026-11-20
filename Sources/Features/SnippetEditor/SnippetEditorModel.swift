import AppKit
import Combine
import CoreData
import SwiftUI

/// Asks the Snippet Editor, open or about to open, to show one snippet.
@MainActor
final class SnippetEditorRequests {
    static let shared = SnippetEditorRequests()
    let reveals = PassthroughSubject<NSManagedObjectID, Never>()
    /// Kept until an editor model takes it, for an editor that is not open yet.
    private(set) var pending: NSManagedObjectID?

    func reveal(_ id: NSManagedObjectID) {
        pending = id
        reveals.send(id)
    }

    func takePending() -> NSManagedObjectID? {
        defer { pending = nil }
        return pending
    }
}

/// State and actions of the Snippet Editor. Edits write to the managed objects and are saved 400ms
/// after the last change; the abbreviation reaches the object only once it is valid.
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
    @Published var abbreviationDraft = ""
    /// Variables the user clicked; the text view inserts each at the caret.
    let insertions = PassthroughSubject<String, Never>()
    @Published var confirmingDelete: Snippet?
    @Published var confirmingGroupDelete: SnippetGroup?
    @Published var renamingGroupID: NSManagedObjectID?

    private var saveWork: DispatchWorkItem?
    private var editingID: NSManagedObjectID?
    private var cancellables: Set<AnyCancellable> = []

    init(context: NSManagedObjectContext) {
        self.context = context
        let center = NotificationCenter.default
        center.publisher(for: NSApplication.willTerminateNotification)
            .merge(with: center.publisher(for: NSWindow.willCloseNotification))
            .sink { [weak self] _ in MainActor.assumeIsolated { self?.flush() } }
            .store(in: &cancellables)
        center.publisher(for: .NSManagedObjectContextDidSave)
            .filter { [context] in ($0.object as? NSManagedObjectContext)?.persistentStoreCoordinator === context.persistentStoreCoordinator }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        SnippetEditorRequests.shared.reveals
            .sink { [weak self] id in MainActor.assumeIsolated { self?.reveal(id) } }
            .store(in: &cancellables)
        if let id = SnippetEditorRequests.shared.takePending() { reveal(id) }
    }

    func reveal(_ id: NSManagedObjectID) {
        _ = SnippetEditorRequests.shared.takePending()
        guard let snippet = try? context.existingObject(with: id) as? Snippet, !snippet.isDeleted else { return }
        filterText = ""
        library = nil
        if let group = snippet.group { collapsedGroups.remove(group.objectID) }
        select(snippet)
    }

    // MARK: - Reading

    var selected: Snippet? {
        guard let selectedID, let snippet = try? context.existingObject(with: selectedID) as? Snippet, !snippet.isDeleted else { return nil }
        return snippet
    }

    var groups: [SnippetGroup] { SnippetGroup.ordered(in: context) }

    func snippets(in group: SnippetGroup) -> [Snippet] {
        group.snippets.filter(matchesFilter).sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    func count(in library: Library) -> Int {
        (try? context.count(for: request(for: library))) ?? 0
    }

    func snippets(in library: Library) -> [Snippet] {
        ((try? context.fetch(request(for: library))) ?? []).filter(matchesFilter)
    }

    private func request(for library: Library) -> NSFetchRequest<Snippet> {
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
        return request
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

    /// Saves what is pending, then selects; an abbreviation draft that never became valid is dropped.
    func select(_ snippet: Snippet?) {
        flush()
        selectedID = snippet?.objectID
        abbreviationDraft = snippet?.abbreviation ?? ""
        if saveState != .saved { saveState = .saved }
    }

    func selectFirstIfNeeded() {
        guard selected == nil else { return }
        select(groups.lazy.flatMap { self.snippets(in: $0) }.first)
    }

    // MARK: - Editing

    var abbreviationDraftError: String? {
        selected == nil ? nil : Self.abbreviationError(abbreviationDraft)
    }

    func abbreviationEdited(_ draft: String) {
        abbreviationDraft = draft
        guard let snippet = selected, Self.abbreviationError(draft) == nil, snippet.abbreviation != draft else { return }
        snippet.abbreviation = draft
        edited()
    }

    /// Call after every edit to the selected snippet.
    func edited() {
        editingID = selectedID
        if saveState != .saving { saveState = .saving }
        saveWork?.cancel()
        let work = DispatchWorkItem { [self] in
            MainActor.assumeIsolated { self.commit() }
        }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    /// Saves a pending edit now instead of waiting for the debounce.
    func flush() {
        guard saveWork != nil else { return }
        commit()
    }

    private func commit() {
        saveWork?.cancel()
        saveWork = nil
        if let editingID, let snippet = try? context.existingObject(with: editingID) as? Snippet, !snippet.isDeleted {
            snippet.updatedAt = Date()
        }
        editingID = nil
        if save() { saveState = .saved }
    }

    /// The other enabled snippet that the same typed text would also expand, if any.
    func conflict(for snippet: Snippet) -> Snippet? {
        guard snippet.isEnabled, snippet.group?.isEnabled != false else { return nil }
        let request = Snippet.fetchRequest()
        request.predicate = NSPredicate(
            format: "abbreviation ==[c] %@ AND isEnabled == YES AND (group == nil OR group.isEnabled == YES) AND self != %@",
            snippet.abbreviation, snippet
        )
        let candidates = (try? context.fetch(request)) ?? []
        return candidates.first { other in
            !(snippet.caseSensitive && other.caseSensitive && snippet.abbreviation != other.abbreviation)
        }
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
        filterText = ""
        library = nil
        let group = selected?.group ?? groups.first ?? newGroup(select: false)
        let snippet = Snippet.insert(title: L("editor_new_snippet"), abbreviation: ".new", content: "", group: group, in: context)
        collapsedGroups.remove(group.objectID)
        save()
        select(snippet)
    }

    func duplicate(_ snippet: Snippet) {
        let copy = Snippet(context: context)
        copy.id = UUID()
        copy.title = snippet.title
        copy.abbreviation = Snippet.uniqueAbbreviation(snippet.abbreviation, in: context)
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
        if selectedID == snippet.objectID { select(nil) }
        context.delete(snippet)
        save()
        selectFirstIfNeeded()
    }

    @discardableResult
    func newGroup(select: Bool = true) -> SnippetGroup {
        let group = SnippetGroup.insert(named: L("editor_new_group"), in: context)
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
        if let selected, selected.group == group { select(nil) }
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
                guard let self, !snippet.isDeleted, snippet.managedObjectContext != nil,
                      !(snippet.appRules ?? []).contains(where: { $0.bundleIdentifier == bundleID }) else { return }
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

    /// Saves the context; on failure rolls back, so one bad change cannot block every later save.
    @discardableResult
    func save() -> Bool {
        defer { objectWillChange.send() }
        guard context.hasChanges else { return true }
        do {
            try context.save()
            return true
        } catch {
            Log.ui.error("Could not save snippets: \(error.localizedDescription, privacy: .public)")
            context.rollback()
            saveState = .invalid(error.localizedDescription)
            return false
        }
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
