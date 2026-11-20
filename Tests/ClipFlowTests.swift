import AppKit
import CoreData
import XCTest
@testable import ClipFlow

extension XCTestCase {
    /// An empty defaults suite named after the test: runs reuse its file, and parallel workers never share one.
    func makeTestDefaults(_ purpose: String) -> UserDefaults {
        let testName = self.name.filter { $0.isLetter || $0.isNumber }
        let name = "\(purpose)-\(testName)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return defaults
    }
}

final class AbbreviationMatcherTests: XCTestCase {
    private func candidate(
        _ abbreviation: String,
        trigger: ExpandTrigger = .delimiter,
        caseSensitive: Bool = false,
        allowed: Set<String>? = nil,
        denied: Set<String> = []
    ) -> ExpansionCandidate {
        ExpansionCandidate(id: abbreviation, abbreviation: abbreviation, trigger: trigger, caseSensitive: caseSensitive, allowedApps: allowed, deniedApps: denied)
    }

    func testDelimiterTriggerDeletesAbbreviationAndTriggerAndKeepsTheSpace() {
        let match = AbbreviationMatcher.match(buffer: "hello .sig ", candidates: [candidate(".sig")], frontmostApp: "app")
        XCTAssertEqual(match, AbbreviationMatch(candidateID: ".sig", deleteCount: 5, trailingText: " "))
    }

    func testTabAndEnterTriggersAreConsumed() {
        XCTAssertEqual(AbbreviationMatcher.match(buffer: ".sig\t", candidates: [candidate(".sig", trigger: .tab)], frontmostApp: "app")?.trailingText, "")
        XCTAssertEqual(AbbreviationMatcher.match(buffer: ".sig\r", candidates: [candidate(".sig", trigger: .enter)], frontmostApp: "app")?.deleteCount, 5)
        XCTAssertNil(AbbreviationMatcher.match(buffer: ".sig ", candidates: [candidate(".sig", trigger: .tab)], frontmostApp: "app"))
    }

    func testDelimiterTriggerIgnoresTabAndReturnBecauseTheyMoveFocusOrSend() {
        XCTAssertNil(AbbreviationMatcher.match(buffer: ".sig\t", candidates: [candidate(".sig")], frontmostApp: "app"))
        XCTAssertNil(AbbreviationMatcher.match(buffer: ".sig\r", candidates: [candidate(".sig")], frontmostApp: "app"))
        XCTAssertNotNil(AbbreviationMatcher.match(buffer: ".sig,", candidates: [candidate(".sig")], frontmostApp: "app"))
    }

    func testAnyTriggerExpandsAsSoonAsTheAbbreviationIsTyped() {
        let match = AbbreviationMatcher.match(buffer: "x .sig", candidates: [candidate(".sig", trigger: .any)], frontmostApp: "app")
        XCTAssertEqual(match, AbbreviationMatch(candidateID: ".sig", deleteCount: 4, trailingText: ""))
    }

    func testAbbreviationGluedToAWordDoesNotExpand() {
        XCTAssertNil(AbbreviationMatcher.match(buffer: "file.sig ", candidates: [candidate(".sig")], frontmostApp: "app"))
    }

    func testCaseSensitivity() {
        XCTAssertNotNil(AbbreviationMatcher.match(buffer: ".SIG ", candidates: [candidate(".sig")], frontmostApp: "app"))
        XCTAssertNil(AbbreviationMatcher.match(buffer: ".SIG ", candidates: [candidate(".sig", caseSensitive: true)], frontmostApp: "app"))
    }

    func testAppRules() {
        let onlyMail = candidate(".sig", allowed: ["com.apple.mail"])
        XCTAssertNil(AbbreviationMatcher.match(buffer: ".sig ", candidates: [onlyMail], frontmostApp: "com.apple.Safari"))
        XCTAssertNotNil(AbbreviationMatcher.match(buffer: ".sig ", candidates: [onlyMail], frontmostApp: "com.apple.mail"))

        let notXcode = candidate(".sig", denied: ["com.apple.dt.Xcode"])
        XCTAssertNil(AbbreviationMatcher.match(buffer: ".sig ", candidates: [notXcode], frontmostApp: "com.apple.dt.Xcode"))
    }

    func testLongestAbbreviationWinsWhenSortedFirst() {
        let candidates = [candidate(".sig2"), candidate(".sig")]
        XCTAssertEqual(AbbreviationMatcher.match(buffer: ".sig2 ", candidates: candidates, frontmostApp: "app")?.candidateID, ".sig2")
    }

    func testHebrewAbbreviation() {
        XCTAssertNotNil(AbbreviationMatcher.match(buffer: "שלום ;חת ", candidates: [candidate(";חת")], frontmostApp: "app"))
    }

    func testTypingBufferKeepsTheTailAndHandlesBackspace() {
        var buffer = TypingBuffer(maxLength: 4)
        buffer.append("abcdef")
        XCTAssertEqual(buffer.text, "cdef")
        buffer.deleteBackward()
        XCTAssertEqual(buffer.text, "cde")
        buffer.reset()
        buffer.deleteBackward()
        XCTAssertEqual(buffer.text, "")
    }
}

final class SnippetTemplateTests: XCTestCase {
    private let context = TemplateContext(
        now: Date(timeIntervalSince1970: 1_778_400_000),
        timeZone: TimeZone(identifier: "Asia/Jerusalem")!,
        locale: Locale(identifier: "en_US_POSIX"),
        clipboard: "copied text"
    )

    func testDateTimeAndClipboardVariables() {
        let rendered = SnippetTemplate.render("{date:yyyy-MM-dd} {time:HH:mm} [{clipboard}]", context: context)
        XCTAssertEqual(rendered.text, "2026-05-10 11:00 [copied text]")
        XCTAssertEqual(rendered.cursorOffsetFromEnd, 0)
    }

    func testCursorPositionIsCountedFromTheEnd() {
        let rendered = SnippetTemplate.render("<div>{cursor}</div>", context: context)
        XCTAssertEqual(rendered.text, "<div></div>")
        XCTAssertEqual(rendered.cursorOffsetFromEnd, 6)
    }

    func testPromptSyntaxes() {
        let content = "Hi {prompt:Name}, call {phone:prompt=\"Phone number\"} or {prompt:Name}"
        XCTAssertEqual(SnippetTemplate.prompts(in: content), [
            SnippetPrompt(key: "Name", label: "Name"),
            SnippetPrompt(key: "phone", label: "Phone number")
        ])

        var filled = context
        filled.promptValues = ["Name": "Dana", "phone": "050"]
        XCTAssertEqual(SnippetTemplate.render(content, context: filled).text, "Hi Dana, call 050 or Dana")
    }

    func testUnknownTokensStayAsTyped() {
        XCTAssertEqual(SnippetTemplate.render("const x = {a: 1}", context: context).text, "const x = {a: 1}")
    }
}

final class PasteboardSnapshotTests: XCTestCase {
    func testRoundTripKeepsEveryItemAndType() throws {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("clipflow-test-\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }

        pasteboard.clearContents()
        let item = NSPasteboardItem()
        item.setString("plain", forType: .string)
        item.setData(Data("{\\rtf1 rich}".utf8), forType: .rtf)
        pasteboard.writeObjects([item])

        let snapshot = try XCTUnwrap(PasteboardSnapshot.capture(from: pasteboard))
        let decoded = try PasteboardSnapshot.decoded(from: snapshot.encoded())
        XCTAssertEqual(decoded, snapshot)

        pasteboard.clearContents()
        pasteboard.setString("something else", forType: .string)
        decoded.write(to: pasteboard)

        XCTAssertEqual(pasteboard.string(forType: .string), "plain")
        XCTAssertEqual(pasteboard.data(forType: .rtf), Data("{\\rtf1 rich}".utf8))
    }

    func testPrivateMarkersAndSizeLimit() {
        XCTAssertTrue(PasteboardSnapshot.text("secret", transient: true).isPrivate)
        XCTAssertFalse(PasteboardSnapshot.text("public", transient: false).isPrivate)

        let pasteboard = NSPasteboard(name: NSPasteboard.Name("clipflow-test-\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        pasteboard.setString(String(repeating: "x", count: 100), forType: .string)
        XCTAssertNil(PasteboardSnapshot.capture(from: pasteboard, maxBytes: 10))
    }

    func testClassification() {
        XCTAssertEqual(ClipCapture.classify(.text("https://github.com/relbns/ClipFlow", transient: false))?.kind, .url)
        XCTAssertEqual(ClipCapture.classify(.text("#FF5733", transient: false))?.kind, .color)
        XCTAssertEqual(ClipCapture.classify(.text("hello world", transient: false))?.kind, .text)
        XCTAssertNil(ClipCapture.classify(.text("   ", transient: false)))
        XCTAssertEqual(
            ClipCapture.classify(.text("same", transient: false))?.hash,
            ClipCapture.classify(.text("same", transient: false))?.hash
        )
    }
}

final class StorageTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("clipflow-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testStoreWrittenByModelV1IsMigratedAndKeepsItsSnippets() throws {
        let storeURL = directory.appendingPathComponent("ClipFlow.sqlite")
        try writeV1Store(at: storeURL)

        let stack = CoreDataStack(storeURL: storeURL)
        let snippets = try stack.viewContext.fetch(Snippet.fetchRequest())
        XCTAssertEqual(snippets.map(\.abbreviation), [".sig"])

        let rule = try XCTUnwrap(snippets.first?.appRules?.first)
        XCTAssertTrue(rule.isEnabled)
        XCTAssertFalse(rule.isDeny)
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("ClipFlow-v1-backup.sqlite").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("ClipFlow-migrating.sqlite").path))
    }

    /// Set CLIPFLOW_STORE_FIXTURE to a copy of a real store to check it is recognised as v1 or v2.
    func testRealStoreFixtureIsAKnownModelVersion() throws {
        guard let path = ProcessInfo.processInfo.environment["CLIPFLOW_STORE_FIXTURE"] else {
            throw XCTSkip("No store fixture given")
        }
        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(ofType: NSSQLiteStoreType, at: URL(fileURLWithPath: path))
        let known = NSManagedObjectModel.knownVersions.contains { NSManagedObjectModel.clipFlowModel(version: $0, bindClasses: false).isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata) }
        XCTAssertTrue(known)
    }

    func testDuplicateGroupsAndSnippetsAreMerged() throws {
        let stack = CoreDataStack(storeURL: nil)
        let context = stack.viewContext
        for offset in 0..<3 {
            let group = makeGroup("Personal", in: context, createdAt: Date(timeIntervalSince1970: Double(offset)))
            makeSnippet(".time", in: group, useCount: 1)
        }
        try context.save()

        SnippetLibraryRepair.mergeDuplicates(in: context)

        let groups = try context.fetch(SnippetGroup.fetchRequest())
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups.first?.snippets.count, 1)
        XCTAssertEqual(groups.first?.snippets.first?.useCount, 3)
    }

    func testGroupsTheUserCreatedAreNeverMerged() throws {
        let stack = CoreDataStack(storeURL: nil)
        let context = stack.viewContext
        for offset in 0..<2 {
            let group = makeGroup("New Group", in: context, createdAt: Date(timeIntervalSince1970: Double(offset)))
            makeSnippet(".x\(offset)", in: group, useCount: 0)
        }
        try context.save()

        SnippetLibraryRepair.mergeDuplicates(in: context)

        XCTAssertEqual(try context.count(for: SnippetGroup.fetchRequest()), 2)
    }

    func testStoreWrittenByModelV2IsMigratedToTheCurrentModel() throws {
        let storeURL = directory.appendingPathComponent("ClipFlow.sqlite")
        let model = NSManagedObjectModel.clipFlowModel(version: 2, bindClasses: false)
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let store = try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: nil)
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        let snippet = NSEntityDescription.insertNewObject(forEntityName: "Snippet", into: context)
        snippet.setValuesForKeys(["id": UUID(), "title": "Date", "abbreviation": ".dd", "content": "{date}", "createdAt": Date(), "updatedAt": Date()])
        try context.save()
        try coordinator.remove(store)

        let stack = CoreDataStack(storeURL: storeURL)
        let migrated = try XCTUnwrap(try stack.viewContext.fetch(Snippet.fetchRequest()).first)
        XCTAssertEqual(migrated.abbreviation, ".dd")
        XCTAssertFalse(migrated.isFavorite)
    }

    func testStoreFromANewerVersionIsLeftUntouched() throws {
        let storeURL = directory.appendingPathComponent("ClipFlow.sqlite")
        let newer = NSManagedObjectModel.clipFlowModel(version: NSManagedObjectModel.currentVersion, bindClasses: false)
        let extra = NSEntityDescription()
        extra.name = "FutureEntity"
        extra.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        newer.entities.append(extra)
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: newer)
        let store = try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: nil)
        try coordinator.remove(store)
        let before = try Data(contentsOf: storeURL)

        let stack = CoreDataStack(storeURL: storeURL)

        XCTAssertEqual(stack.loadIssue, .newerVersion)
        XCTAssertEqual(try Data(contentsOf: storeURL), before)
    }

    func testMovingAStoreAsideTakesItsExternalDataWithIt() throws {
        let storeURL = directory.appendingPathComponent("ClipFlow.sqlite")
        try Data("db".utf8).write(to: storeURL)
        let external = StoreMigrator.externalDataFolder(of: storeURL)
        try FileManager.default.createDirectory(at: external, withIntermediateDirectories: true)

        let moved = try XCTUnwrap(StoreMigrator.moveAside(storeURL: storeURL, suffix: "unreadable"))

        XCTAssertFalse(FileManager.default.fileExists(atPath: external.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: StoreMigrator.externalDataFolder(of: moved).path))
    }

    func testStarterSnippetsAreSeededOnceAndOnlyIntoAnEmptyStore() throws {
        let stack = CoreDataStack(storeURL: nil)
        stack.prepareDefaultData(defaults: makeTestDefaults("clipflow-tests-seed-first"))
        stack.prepareDefaultData(defaults: makeTestDefaults("clipflow-tests-seed-second"))

        XCTAssertEqual(try stack.viewContext.count(for: SnippetGroup.fetchRequest()), 1)
        XCTAssertEqual(try stack.viewContext.count(for: Snippet.fetchRequest()), 4)
    }

    // MARK: - Helpers

    @discardableResult
    private func makeGroup(_ name: String, in context: NSManagedObjectContext, createdAt: Date) -> SnippetGroup {
        let group = SnippetGroup(context: context)
        group.id = UUID()
        group.name = name
        group.createdAt = createdAt
        return group
    }

    private func makeSnippet(_ abbreviation: String, in group: SnippetGroup, useCount: Int32) {
        let snippet = Snippet(context: group.managedObjectContext!)
        snippet.id = UUID()
        snippet.title = "Current Time"
        snippet.abbreviation = abbreviation
        snippet.content = "{time}"
        snippet.createdAt = group.createdAt
        snippet.updatedAt = group.createdAt
        snippet.useCount = useCount
        snippet.group = group
    }

    private func writeV1Store(at url: URL) throws {
        let model = NSManagedObjectModel.clipFlowModel(version: 1, bindClasses: false)
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let store = try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: nil)
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator

        let snippet = NSEntityDescription.insertNewObject(forEntityName: "Snippet", into: context)
        snippet.setValuesForKeys([
            "id": UUID(), "title": "Signature", "abbreviation": ".sig", "content": "Best",
            "createdAt": Date(), "updatedAt": Date()
        ])
        let rule = NSEntityDescription.insertNewObject(forEntityName: "AppRule", into: context)
        rule.setValuesForKeys(["id": UUID(), "bundleIdentifier": "com.apple.mail", "appName": "Mail"])
        rule.setValue(snippet, forKey: "snippet")

        try context.save()
        try coordinator.remove(store)
    }
}

@MainActor
final class PopoverNavigationTests: XCTestCase {
    private var monitor: ClipboardMonitor!
    private var defaults: UserDefaults!
    private let navigation = PopoverNavigation.shared

    private var stack: CoreDataStack!

    override func setUp() async throws {
        stack = CoreDataStack(storeURL: nil)
        defaults = makeTestDefaults("clipflow-tests-navigation")
        AppDefaults.register(in: defaults)
        monitor = ClipboardMonitor(context: stack.viewContext, defaults: defaults)
        let base = Date()
        let texts = (1...11).map { "clip \($0)" } + ["https://example.com", "#FF5733"]
        for (offset, text) in texts.enumerated() {
            let snapshot = PasteboardSnapshot.text(text, transient: false)
            monitor.record(ClipCapture.classify(snapshot)!, snapshot: snapshot, sourceName: nil, sourceBundleID: nil, at: base.addingTimeInterval(Double(offset)))
        }
        navigation.clipboardMonitor = monitor
        navigation.defaults = defaults
        navigation.searchText = ""
        navigation.goBack()
        navigation.context = stack.viewContext
        navigation.reloadSnippets()
    }

    override func tearDown() async throws {
        navigation.clipboardMonitor = nil
        navigation.context = nil
        navigation.reloadSnippets()
        navigation.defaults = .standard
        _ = SnippetEditorRequests.shared.takePending()
    }

    private func numbers(_ items: [PopoverItem]) -> [Int?] {
        items.compactMap { if case .clip(_, let number) = $0 { return number }; return nil }
    }

    func testSimpleModeNumbersTheFirstTenClips() {
        defaults.set("simple", forKey: "viewMode")
        let items = navigation.items
        XCTAssertEqual(items.count, 13)
        XCTAssertEqual(numbers(items).prefix(11).map { $0 }, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, nil])
    }

    func testOrganizedModeShowsCategoriesAndDrillsIn() {
        defaults.set("organized", forKey: "viewMode")
        XCTAssertEqual(navigation.sections.map(\.id), ["categories"])
        XCTAssertFalse(navigation.handle(.init(keyCode: 19, characters: "2")), "a digit with no numbered row goes to the search field")
        XCTAssertTrue(navigation.handle(.init(keyCode: 125)))
        XCTAssertTrue(navigation.handle(.init(keyCode: 125)))
        XCTAssertEqual(navigation.selectedID, "category-links")
        XCTAssertTrue(navigation.handle(.init(keyCode: 36)))
        XCTAssertEqual(navigation.drilledCategory, .links)
        XCTAssertEqual(navigation.items.count, 1)
        XCTAssertTrue(navigation.handle(.init(keyCode: 53)))
        XCTAssertNil(navigation.drilledCategory)
    }

    func testDigitsPasteOnlyWithAnEmptySearchAndModifiersPassThrough() {
        defaults.set("simple", forKey: "viewMode")
        XCTAssertTrue(navigation.handle(.init(keyCode: 18, characters: "1")))
        XCTAssertFalse(navigation.handle(.init(keyCode: 125, modifiers: .other)))
        navigation.searchText = "clip 1"
        XCTAssertFalse(navigation.handle(.init(keyCode: 18, characters: "1")))
        XCTAssertEqual(navigation.sections.first?.id, "results")
        XCTAssertEqual(navigation.items.count, 3)
    }

    func testPinnedClipsGetCommandSlots() {
        defaults.set("organized", forKey: "viewMode")
        let pinnedClip = monitor.clipHistory[2]
        monitor.setPinned(pinnedClip, true)
        guard case .pinned(_, let slot)? = navigation.sections.first?.items.first else {
            return XCTFail("expected a pinned row first")
        }
        XCTAssertEqual(slot, 1)
        XCTAssertTrue(navigation.handle(.init(keyCode: 51, modifiers: .option)), "⌥⌫ deletes a pinned row too")
        XCTAssertFalse(monitor.clipHistory.contains { $0.id == pinnedClip.id })
    }

    @discardableResult
    private func addSnippet(_ abbreviation: String, to group: SnippetGroup, uses: Int32 = 0, enabled: Bool = true) -> Snippet {
        let snippet = Snippet.insert(title: "Title \(abbreviation)", abbreviation: abbreviation, content: "Body of \(abbreviation)", group: group, in: stack.viewContext)
        snippet.useCount = uses
        snippet.isEnabled = enabled
        return snippet
    }

    func testAllSnippetsRowOpensEveryEnabledSnippetByGroup() throws {
        defaults.set("organized", forKey: "viewMode")
        let work = SnippetGroup.insert(named: "Work", in: stack.viewContext)
        let home = SnippetGroup.insert(named: "Home", in: stack.viewContext)
        let hidden = SnippetGroup.insert(named: "Hidden", in: stack.viewContext)
        hidden.isEnabled = false
        addSnippet(".a", to: work, uses: 1)
        addSnippet(".b", to: work, uses: 9)
        addSnippet(".c", to: work)
        addSnippet(".d", to: home, uses: 5)
        addSnippet(".off", to: home, enabled: false)
        addSnippet(".hidden", to: hidden, uses: 50)
        try stack.viewContext.save()
        navigation.reloadSnippets()

        let snippetRows = navigation.sections.last?.items.map(\.id) ?? []
        XCTAssertEqual(snippetRows.count, 4, "three most-used snippets, then the row that opens the rest")
        XCTAssertEqual(snippetRows.last, "all-snippets")
        guard case .snippet(let mostUsed)? = navigation.sections.last?.items.first else { return XCTFail("expected a snippet first") }
        XCTAssertEqual(mostUsed.abbreviation, ".b")

        navigation.activate(.allSnippets(count: 4))
        XCTAssertEqual(navigation.sections.map(\.title), ["Work", "Home"])
        XCTAssertEqual(navigation.sections.map(\.items.count), [3, 1])
        XCTAssertTrue(navigation.handle(.init(keyCode: 53)), "Escape goes back before it closes")
        XCTAssertFalse(navigation.isDrilled)
    }

    func testSearchListsMatchingSnippetsAfterClips() throws {
        let group = SnippetGroup.insert(named: "Work", in: stack.viewContext)
        addSnippet(".sig", to: group)
        try stack.viewContext.save()
        navigation.reloadSnippets()

        navigation.searchText = ".sig"
        XCTAssertEqual(navigation.sections.map(\.id), ["snippet-results"], "no clip matches, so only the snippets show")
        navigation.searchText = "clip 1"
        XCTAssertEqual(navigation.sections.map(\.id), ["results"])
        navigation.searchText = "of .sig"
        XCTAssertEqual(navigation.sections.first?.items.count, 1, "content matches too")
    }

    func testSearchRanksTheClosestMatchFirstAndAcceptsInitials() {
        navigation.searchText = "clip 1"
        let first = navigation.items.first.flatMap { item -> String? in
            if case .clip(let clip, _) = item { return clip.content }
            return nil
        }
        XCTAssertEqual(first, "clip 1", "the exact title ranks before the newer clips that only start with it")
        navigation.searchText = "hec"
        XCTAssertEqual(navigation.items.count, 1, "h-e-c in order matches https://example.com only")
    }

    func testGoingBackSelectsTheRowThatWasOpened() {
        defaults.set("organized", forKey: "viewMode")
        navigation.activate(.category(.links, count: 1))
        XCTAssertTrue(navigation.handle(.init(keyCode: 53)))
        XCTAssertEqual(navigation.selectedID, "category-links")
    }

    func testSavingAClipAsASnippetTakesAFreeAbbreviationAndOpensIt() throws {
        let group = SnippetGroup.insert(named: "Work", in: stack.viewContext)
        addSnippet(".clip", to: group)
        try stack.viewContext.save()
        let clip = try XCTUnwrap(monitor.clipHistory.first { $0.content == "clip 3" })

        let snippet = try XCTUnwrap(navigation.saveAsSnippet(clip, in: group.objectID))
        XCTAssertEqual(snippet.abbreviation, ".clip2")
        XCTAssertEqual(snippet.content, "clip 3")
        XCTAssertEqual(snippet.group, group)
        XCTAssertEqual(SnippetEditorRequests.shared.pending, snippet.objectID)
        XCTAssertFalse(stack.viewContext.hasChanges)
    }
}

final class FuzzyMatchTests: XCTestCase {
    func testTiersRankExactThenPrefixThenWordThenAnywhereThenGaps() {
        let cases: [(query: String, text: String, score: Int?)] = [
            (".sig", ".sig", FuzzyMatch.exact),
            ("SIG", ".sig", FuzzyMatch.wordStart),
            ("email", "Email signature", FuzzyMatch.prefix),
            ("sign", "Email signature", FuzzyMatch.wordStart),
            ("nat", "Email signature", FuzzyMatch.substring),
            ("cafe", "Café menu", FuzzyMatch.prefix),
            ("חתי", "חתימה", FuzzyMatch.prefix),
            ("sgi", "Email signature", nil),
            ("x", "Email signature", nil),
            ("", "Email signature", nil)
        ]
        for item in cases {
            XCTAssertEqual(FuzzyMatch.score(item.query, in: item.text), item.score, "\(item.query) in \(item.text)")
        }
    }

    func testGapsMatchInOrderAndPreferWordStarts() throws {
        let initials = try XCTUnwrap(FuzzyMatch.score("esig", in: "Email signature"))
        let scattered = try XCTUnwrap(FuzzyMatch.score("eint", in: "Email signature"))
        XCTAssertLessThan(initials, FuzzyMatch.substring)
        XCTAssertGreaterThan(initials, scattered)
        XCTAssertNil(FuzzyMatch.score("esig", in: "Email signature", allowGaps: false))
    }
}

final class OKLCHTests: XCTestCase {
    func testDesignTokensConvertLikeABrowser() {
        XCTAssertEqual(OKLCH(0.60, 0.17, 272).hex, "#5F74E4")
        XCTAssertEqual(OKLCH(0.78, 0.14, 70).hex, "#F0A646")
        XCTAssertEqual(OKLCH(0.70, 0.17, 145).hex, "#4DB956")
        XCTAssertEqual(OKLCH(0.70, 0.17, 60).hex, "#E88000")
        XCTAssertEqual(OKLCH(0.55, 0.03, 250).hex, "#657383")
    }

    func testExtremesAndGamutClipping() {
        XCTAssertEqual(OKLCH(1, 0, 0).hex, "#FFFFFF")
        XCTAssertEqual(OKLCH(0, 0, 0).hex, "#000000")
        XCTAssertEqual(OKLCH(0.9, 0.4, 145).hex.count, 7)
    }
}

final class OKLCHDisplayP3Tests: XCTestCase {
    func testColorsOutsideSRGBStayInsideDisplayP3() {
        for color in [OKLCH(0.86, 0.12, 272), OKLCH(0.74, 0.17, 280), OKLCH(0.85, 0.15, 60)] {
            let (red, green, blue) = color.displayP3
            XCTAssertTrue([red, green, blue].allSatisfy { $0 > 0 && $0 < 1 }, "\(color) clips in Display P3")
        }
    }
}

@MainActor
final class LanguageAndExclusionTests: XCTestCase {
    func testSystemLanguageResolvesToASupportedTranslation() {
        XCTAssertEqual(LanguageManager.resolve(["he-IL", "en-US"]), "he")
        XCTAssertEqual(LanguageManager.resolve(["iw"]), "he")
        XCTAssertEqual(LanguageManager.resolve(["fr-FR", "en-GB"]), "en")
        XCTAssertEqual(LanguageManager.resolve(["fr-FR"]), "en")
        XCTAssertEqual(LanguageManager.resolve([]), "en")
    }

    func testAnAppIsExcludedPerScopeWithASingleEntry() {
        var apps: [ExcludedApp] = []
        apps = apps.adding(bundleID: "com.1password", name: "1Password", to: .history)
        apps = apps.adding(bundleID: "com.1password", name: "1Password", to: .expansion)
        XCTAssertEqual(apps.count, 1)
        XCTAssertTrue(apps[0].excludeFromHistory && apps[0].excludeFromExpansion)

        apps = apps.removing(bundleID: "com.1password", from: .history)
        XCTAssertEqual(apps.count, 1)
        XCTAssertFalse(apps[0].excludeFromHistory)

        apps = apps.removing(bundleID: "com.1password", from: .expansion)
        XCTAssertTrue(apps.isEmpty)
    }

    func testOldExclusionJSONStillDecodes() {
        let json = #"[{"id":"4F1C0E2A-1111-2222-3333-444455556666","bundleID":"com.apple.Terminal","name":"Terminal","excludeFromHistory":true,"excludeFromExpansion":false}]"#
        XCTAssertEqual(AppExclusions.decode(json).map(\.bundleID), ["com.apple.Terminal"])
    }
}

@MainActor
final class SnippetEditorModelTests: XCTestCase {
    func testAnInvalidAbbreviationNeverReachesTheStoreAndLeavingKeepsTheOtherEdits() throws {
        let context = CoreDataStack(storeURL: nil).viewContext
        let model = SnippetEditorModel(context: context)
        model.newSnippet()
        let first = try XCTUnwrap(model.selected)
        model.abbreviationEdited(".sig")
        model.flush()

        model.abbreviationEdited("sig")
        first.content = "Best regards"
        model.edited()
        model.toggleFavorite(first)
        context.refresh(first, mergeChanges: true)
        XCTAssertEqual(first.abbreviation, ".sig")
        XCTAssertNotNil(model.abbreviationDraftError)

        model.newSnippet()
        XCTAssertNil(model.abbreviationDraftError)
        context.refresh(first, mergeChanges: false)
        XCTAssertEqual(first.abbreviation, ".sig")
        XCTAssertEqual(first.content, "Best regards")
    }
}

final class PreviousBundleIDTests: XCTestCase {
    private var previous: String { "clipflow-tests-previous-id-\(name.filter { $0.isLetter || $0.isNumber })" }
    private var current: String { "clipflow-tests-current-id-\(name.filter { $0.isLetter || $0.isNumber })" }
    private let defaults = UserDefaults.standard

    override func tearDown() {
        for name in [previous, current] {
            defaults.removePersistentDomain(forName: name)
        }
    }

    func testSettingsMoveOnceAndDoNotComeBackAfterAReset() {
        defaults.setPersistentDomain(["viewMode": "simple", "AppleLanguages": ["he"]], forName: previous)

        PreviousBundleID.migrateDefaultsIfNeeded(defaults: defaults, from: previous, to: current)
        XCTAssertEqual(defaults.persistentDomain(forName: current)?["viewMode"] as? String, "simple")
        XCTAssertNil(defaults.persistentDomain(forName: previous))

        defaults.removePersistentDomain(forName: current)
        PreviousBundleID.migrateDefaultsIfNeeded(defaults: defaults, from: previous, to: current)
        XCTAssertTrue(defaults.persistentDomain(forName: current)?.isEmpty ?? true)
    }

    func testExistingSettingsAreKeptAndTheOldOnesRemoved() {
        defaults.setPersistentDomain(["viewMode": "simple"], forName: previous)
        defaults.setPersistentDomain(["viewMode": "organized"], forName: current)

        PreviousBundleID.migrateDefaultsIfNeeded(defaults: defaults, from: previous, to: current)
        XCTAssertEqual(defaults.persistentDomain(forName: current)?["viewMode"] as? String, "organized")
        XCTAssertNil(defaults.persistentDomain(forName: previous))
    }
}
