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

    func testStoreWrittenByModelV3KeepsItsClipsWithNoTextReadYet() throws {
        let storeURL = directory.appendingPathComponent("ClipFlow.sqlite")
        let model = NSManagedObjectModel.clipFlowModel(version: 3, bindClasses: false)
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let store = try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: nil)
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        let clip = NSEntityDescription.insertNewObject(forEntityName: "ClipItem", into: context)
        clip.setValuesForKeys(["id": UUID(), "content": "Image", "type": "image", "createdAt": Date(), "dataHash": "h"])
        try context.save()
        try coordinator.remove(store)

        let stack = CoreDataStack(storeURL: storeURL)
        let migrated = try XCTUnwrap(try stack.viewContext.fetch(ClipItem.fetchRequest()).first)
        XCTAssertEqual(migrated.type, "image")
        XCTAssertNil(migrated.recognizedText)
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
        monitor = ClipboardMonitor(context: stack.viewContext, pasteboard: NSPasteboard(name: .init("clipflow-tests")), defaults: defaults)
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

    func testAScreenshotIsFoundByItsTextAndReadImagesAreNotReadAgain() throws {
        let image = NSImage(size: NSSize(width: 4, height: 4), flipped: false) { rect in
            NSColor.red.setFill()
            rect.fill()
            return true
        }
        let png = try XCTUnwrap(NSBitmapImageRep(data: try XCTUnwrap(image.tiffRepresentation))?.representation(using: .png, properties: [:]))
        monitor.recordScreenshot(png, recognizedText: "Quarterly revenue table")
        XCTAssertNil(monitor.nextImageToRecognize(), "a screenshot arrives with its text already read")

        navigation.searchText = "revenue"
        guard case .clip(let found, _)? = navigation.items.first else { return XCTFail("expected the screenshot") }
        XCTAssertEqual(found.kind, .image)

        let snapshot = PasteboardSnapshot(items: [[NSPasteboard.PasteboardType.png.rawValue: png + Data([0])]])
        monitor.record(try XCTUnwrap(ClipCapture.classify(snapshot)), snapshot: snapshot, sourceName: nil, sourceBundleID: nil)
        let next = try XCTUnwrap(monitor.nextImageToRecognize())
        XCTAssertNil(monitor.nextImageToRecognize(excluding: [next.id]), "an image already tried is skipped")
        monitor.setRecognizedText("", forClipID: next.id)
        XCTAssertNil(monitor.nextImageToRecognize(), "an image with no text is marked read")
    }

    func testACapturedImageIsKeptUnreadForTheBackgroundPass() throws {
        let image = NSImage(size: NSSize(width: 4, height: 4), flipped: false) { rect in
            NSColor.blue.setFill()
            rect.fill()
            return true
        }
        let png = try XCTUnwrap(NSBitmapImageRep(data: try XCTUnwrap(image.tiffRepresentation))?.representation(using: .png, properties: [:]))
        monitor.copyImage(png)
        let captured = try XCTUnwrap(monitor.clipHistory.first { $0.kind == .image })
        XCTAssertEqual(captured.sourceAppName, "ClipFlow")
        XCTAssertNil(captured.recognizedText)
        XCTAssertEqual(monitor.nextImageToRecognize()?.id, captured.id)
    }

    func testNothingIsKeptWhileHistoryRecordingIsOff() throws {
        defaults.set(false, forKey: "startMonitoring")
        let before = monitor.clipHistory.count
        monitor.recordScreenshot(Data([0x89, 0x50]), recognizedText: "secret")
        monitor.copy("text read from the screen")
        XCTAssertEqual(monitor.clipHistory.count, before)
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
        XCTAssertTrue(snippet.abbreviation.hasPrefix(".clip") && snippet.abbreviation != ".clip", snippet.abbreviation)
        XCTAssertEqual(snippet.content, "clip 3")
        XCTAssertEqual(snippet.group, group)
        XCTAssertEqual(SnippetEditorRequests.shared.pending, snippet.objectID)
        XCTAssertFalse(stack.viewContext.hasChanges)
    }
}

final class LayoutConverterTests: XCTestCase {
    private let pair = LayoutPair(first: "en", second: "he", keys: [
        ("a", "ש"), ("k", "ל"), ("u", "ו"), ("o", "ם"), ("t", "א"), ("e", "ק"),
        (",", "ת"), (".", "ץ"), ("/", "."), (";", "ף"), ("1", "1"), ("A", "A")
    ])

    func testConvertsTowardTheLayoutTheLettersDoNotBelongTo() {
        let cases: [(String, LayoutConverter.Result?)] = [
            ("akuo", .init(text: "שלום", toSecond: true)),
            ("שלום", .init(text: "akuo", toSecond: false)),
            ("akuo, tk.", .init(text: "שלוםת אלץ", toSecond: true)),
            ("שלום.", .init(text: "akuo/", toSecond: false)),
            ("akuo 1A", .init(text: "שלום 1A", toSecond: true)),
            ("123 !", nil),
            ("", nil)
        ]
        for (text, expected) in cases {
            XCTAssertEqual(LayoutConverter.convert(text, with: pair), expected, text)
        }
    }

    func testOnlyTheTrailingRunInOneLayoutIsRetyped() {
        XCTAssertEqual(LayoutConverter.trailingRun(of: "שלום akuo", with: pair), " akuo")
        XCTAssertEqual(LayoutConverter.trailingRun(of: "akuo, tk.", with: pair), "akuo, tk.")
        XCTAssertEqual(LayoutConverter.trailingRun(of: "tk שלום", with: pair), " שלום")
        XCTAssertEqual(LayoutConverter.trailingRun(of: "123", with: pair), "123")
    }

    func testThePairIsTheLayoutTheLettersCameFromElseTheMostRecent() {
        let russian = LayoutPair(first: "en", second: "ru", keys: [("a", "ф"), ("k", "л")])
        XCTAssertEqual(LayoutConverter.choosePair(for: "שלום", among: [russian, pair])?.second, "he")
        XCTAssertEqual(LayoutConverter.choosePair(for: "akuo", among: [russian, pair])?.second, "ru", "letters of the current layout go to the most recent other")
    }

    func testTheRealHebrewLayoutRetypesWhatTheKeysMeant() throws {
        guard let real = KeyboardLayouts.pair("com.apple.keylayout.ABC", "com.apple.keylayout.Hebrew") else {
            throw XCTSkip("ABC and Hebrew layouts are not installed")
        }
        XCTAssertEqual(LayoutConverter.convert("akuo", with: real)?.text, "שלום")
        XCTAssertEqual(LayoutConverter.convert("שלום", with: real)?.text, "akuo")
        XCTAssertEqual(LayoutConverter.convert("vhh, mh", with: real)?.text, "היית צי")
    }

    @MainActor
    func testTheTextTypedBeforeAShortcutIsKeptForOneHotkeyOnly() {
        let engine = TextExpansionEngine(context: CoreDataStack(storeURL: nil).viewContext)
        engine.handle(.characters("akuo"))
        engine.handle(.shortcut)
        XCTAssertEqual(engine.takeTextBeforeShortcut(), "akuo")
        XCTAssertNil(engine.takeTextBeforeShortcut())

        engine.handle(.characters("tk"))
        engine.handle(.reset)
        engine.handle(.shortcut)
        XCTAssertNil(engine.takeTextBeforeShortcut(), "a click between typing and the hotkey drops the text")

        engine.handle(.characters("akuo"))
        engine.handle(.shortcut)
        engine.handle(.shortcut)
        XCTAssertNil(engine.takeTextBeforeShortcut(), "another shortcut such as Cmd+Z between typing and the hotkey drops it")
    }
}

final class SmallLimitsTests: XCTestCase {
    private let context = TemplateContext(now: Date(timeIntervalSince1970: 0), timeZone: TimeZone(identifier: "UTC")!,
                                          locale: Locale(identifier: "en_US_POSIX"), clipboard: "CLIP")

    func testEscapedTextExpandsToItselfAndOtherBracesAreUntouched() {
        let clip = "Use {date:yyyy} and {clipboard}, {prompt:Name}, {unknown} or {\"a\":{\"b\":1}}"
        let escaped = SnippetTemplate.escaped(clip)
        XCTAssertEqual(SnippetTemplate.render(escaped, context: context).text, clip)
        XCTAssertTrue(SnippetTemplate.prompts(in: escaped).isEmpty, "an escaped prompt asks for nothing")
        XCTAssertTrue(escaped.hasSuffix("{unknown} or {\"a\":{\"b\":1}}"), "only braces that start a variable change")
        XCTAssertEqual(SnippetTemplate.render("Hello {{name}} {\"a\":{\"b\":1}}", context: context).text,
                       "Hello {{name}} {\"a\":{\"b\":1}}", "existing snippets with other braces expand as before")
        XCTAssertEqual(SnippetTemplate.render("{lbrace}date{rbrace}", context: context).text, "{date}")
    }

    func testEveryItemOfAMultiItemClipIsItsPlainText() {
        let snapshot = PasteboardSnapshot(items: [
            [NSPasteboard.PasteboardType.string.rawValue: Data("first".utf8)],
            [NSPasteboard.PasteboardType.string.rawValue: Data("second".utf8)]
        ])
        XCTAssertEqual(snapshot.allText, "first\nsecond")
        XCTAssertEqual(snapshot.string, "first")

        let files = PasteboardSnapshot(items: [[
            NSPasteboard.PasteboardType.fileURL.rawValue: Data("file:///Users/me/report.pdf".utf8),
            NSPasteboard.PasteboardType.string.rawValue: Data("report.pdf".utf8)
        ]])
        XCTAssertEqual(files.allText, "/Users/me/report.pdf", "a file is its full path, as the clip shows it")
    }

    @MainActor
    func testAFreshAbbreviationNeverStartsAnotherOrStartsWithOne() throws {
        let stack = CoreDataStack(storeURL: nil)
        let group = SnippetGroup.insert(named: "G", in: stack.viewContext)
        _ = Snippet.insert(title: "a", abbreviation: ".clipabc", content: "", group: group, in: stack.viewContext)
        try stack.viewContext.save()
        for _ in 0..<20 {
            let fresh = Snippet.freshAbbreviation(prefix: ".clip", in: stack.viewContext)
            XCTAssertFalse(fresh.hasPrefix(".clipabc") || ".clipabc".hasPrefix(fresh), fresh)
        }
        _ = Snippet.insert(title: "b", abbreviation: ".clip", content: "", group: group, in: stack.viewContext)
        try stack.viewContext.save()
        XCTAssertNotEqual(Snippet.freshAbbreviation(prefix: ".clip", in: stack.viewContext), ".clip", "still unique when a prefix-free one is impossible")
    }
}

final class TextTransformTests: XCTestCase {
    func testEachTransformRewritesItsFixture() {
        let cases: [(TextTransform, String, String?)] = [
            (.uppercase, "Hello world", "HELLO WORLD"),
            (.lowercase, "Hello World", "hello world"),
            (.titleCase, "hello big world", "Hello Big World"),
            (.titleCase, "NASA sent my iPhone", "NASA Sent My iPhone"),
            (.titleCase, "SHOUTING TEXT", "Shouting Text"),
            (.sentenceCase, "hello. how are you?\nfine", "Hello. How are you?\nFine"),
            (.sentenceCase, "i met John in NYC.", "I met John in NYC."),
            (.sentenceCase, "HELLO THERE. BYE", "Hello there. Bye"),
            (.trim, "  padded \n", "padded"),
            (.collapseSpaces, "a   b\t\tc\nd  e", "a b c\nd e"),
            (.collapseSpaces, "\t\tcode  x", "\t\tcode x"),
            (.joinLines, "first line\n  second\r\nthird", "first line second third"),
            (.removeEmptyLines, "a\n\n  \nb", "a\nb"),
            (.removeEmptyLines, "a\r\n\r\nb\r\n", "a\r\nb"),
            (.removeEmptyLines, "a\r\nb", nil),
            (.camelCase, "user ID list", "userIdList"),
            (.camelCase, "שלום עולם", nil),
            (.snakeCase, "userIDList", "user_id_list"),
            (.kebabCase, "Hello World_again", "hello-world-again"),
            (.urlEncode, "a b&c=ש", "a%20b%26c%3D%D7%A9"),
            (.urlDecode, "a%20b%26c", "a b&c"),
            (.base64Encode, "שלום", "16nXnNeV150="),
            (.base64Decode, "16nXnNeV150=", "שלום"),
            (.base64Decode, "not base64 ✗", nil),
            (.base64Decode, "aGVsbG8", "hello"),
            (.base64Decode, "Pz8-Pw", "??>?"),
            (.prettyJSON, "{\"b\":1.10,\"a\":[1e2,{}],\"s\":\"x, {y}: \\\"z\\\"\"}",
             "{\n  \"b\": 1.10,\n  \"a\": [\n    1e2,\n    {}\n  ],\n  \"s\": \"x, {y}: \\\"z\\\"\"\n}"),
            (.prettyJSON, "{broken", nil),
            (.removeNiqqud, "שָׁלוֹם בֵּית־סֵפֶר", "שלום בית־ספר"),
            (.removeNiqqud, "\u{FB2A}\u{FB31}", "שב"),
            (.removeNiqqud, "café", nil),
            (.uppercase, "ALREADY", nil)
        ]
        for (transform, input, expected) in cases {
            XCTAssertEqual(transform.apply(input), expected, "\(transform) on \(input)")
        }
    }

    func testFixLayoutUsesTheGivenLayoutPairs() {
        let pair = LayoutPair(first: "en", second: "he", keys: [("a", "ש"), ("k", "ל"), ("u", "ו"), ("o", "ם")])
        XCTAssertEqual(TextTransform.fixLayout.apply("akuo", layoutPairs: [pair]), "שלום")
        XCTAssertNil(TextTransform.fixLayout.apply("akuo"), "no layouts, no change")
    }
}

final class SyncMergeTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_000)
    private let t1 = Date(timeIntervalSince1970: 2_000)

    func testOnlyRealEditsAndDeletionsOfSyncedKindsAreStamped() {
        let ledger = [
            "snippet:a": SyncLedgerEntry(hash: JSONValue.string("A").stableHash, modifiedAt: t0, deleted: false, device: "m1"),
            "snippet:gone": SyncLedgerEntry(hash: "x", modifiedAt: t0, deleted: false, device: "m1"),
            "setting:viewMode": SyncLedgerEntry(hash: "y", modifiedAt: t0, deleted: false, device: "m1")
        ]
        let stamped = SyncMerge.stamp(
            local: ["snippet:a": .string("A"), "snippet:b": .string("B")], ledger: ledger, kinds: ["snippet"], now: t1, device: "m1"
        )
        XCTAssertEqual(stamped["snippet:a"]?.modifiedAt, t0, "unchanged keeps its time")
        XCTAssertEqual(stamped["snippet:b"]?.modifiedAt, t1)
        XCTAssertEqual(stamped["snippet:gone"]?.deleted, true)
        XCTAssertEqual(stamped["setting:viewMode"]?.deleted, false, "a kind that is not synced is never deleted")
    }

    func testTheNewestRecordWinsAndTiesGoToTheLargerDevice() {
        let ledger = ["snippet:a": SyncLedgerEntry(hash: JSONValue.string("mine").stableHash, modifiedAt: t1, deleted: false, device: "m1")]
        let older = SyncRecord(key: "snippet:a", modifiedAt: t0, deleted: false, payload: .string("old"), device: "m2")
        let tie = SyncRecord(key: "snippet:a", modifiedAt: t1, deleted: false, payload: .string("theirs"), device: "m2")
        XCTAssertTrue(SyncMerge.incoming(remote: [older], ledger: ledger, kinds: ["snippet"]).isEmpty)
        XCTAssertEqual(SyncMerge.incoming(remote: [tie], ledger: ledger, kinds: ["snippet"]).first?.payload, .string("theirs"))
        let deletion = SyncRecord(key: "snippet:a", modifiedAt: t1.addingTimeInterval(1), deleted: true, payload: nil, device: "m0")
        XCTAssertEqual(SyncMerge.incoming(remote: [deletion], ledger: ledger, kinds: ["snippet"]).first?.deleted, true)
        XCTAssertTrue(SyncMerge.incoming(remote: [deletion], ledger: [:], kinds: ["snippet"]).isEmpty, "nothing to delete here")
    }

    func testUntouchedStartersFromAnOldInstallTakeTheFixedIds() throws {
        let context = CoreDataStack(storeURL: nil).viewContext
        let group = SnippetGroup.insert(named: SnippetLibraryRepair.starterGroupName, in: context)
        for starter in StarterSnippets.all {
            _ = Snippet.insert(title: starter.title, abbreviation: starter.abbreviation, content: starter.content, group: group, in: context)
        }
        let edited = try XCTUnwrap(try context.fetch(Snippet.fetchRequest()).first { $0.abbreviation == ".sig" })
        edited.content = "Cheers,\nAriel"
        try context.save()

        XCTAssertTrue(StarterSnippets.adoptFixedIDs(in: context))
        let ids = Dictionary(uniqueKeysWithValues: try context.fetch(Snippet.fetchRequest()).map { ($0.abbreviation, $0.id) })
        for starter in StarterSnippets.all where starter.abbreviation != ".sig" {
            XCTAssertEqual(ids[starter.abbreviation], starter.id)
        }
        XCTAssertNotEqual(ids[".sig"], StarterSnippets.all.last?.id, "an edited starter keeps its own id")
        XCTAssertNotEqual(group.id, StarterSnippets.groupID, "a group holding anything but starters keeps its own id")
        XCTAssertFalse(StarterSnippets.adoptFixedIDs(in: context), "nothing left to adopt")

        context.delete(edited)
        try context.save()
        XCTAssertTrue(StarterSnippets.adoptFixedIDs(in: context))
        XCTAssertEqual(group.id, StarterSnippets.groupID, "a group of starters only takes the fixed id")
    }

    func testALocalEditIsNewerThanWhatItReplacesEvenWithAFastClockElsewhere() {
        let ahead = t1.addingTimeInterval(600)
        let ledger = ["snippet:a": SyncLedgerEntry(hash: "old", modifiedAt: ahead, deleted: false, device: "fast")]
        let stamped = SyncMerge.stamp(local: ["snippet:a": .string("mine")], ledger: ledger, kinds: ["snippet"], now: t1, device: "slow")
        XCTAssertGreaterThan(try XCTUnwrap(stamped["snippet:a"]?.modifiedAt), ahead)
    }

    func testAStaleLiveCopyNeverBringsBackADeletedRecord() {
        let ledger = ["snippet:a": SyncLedgerEntry(hash: "", modifiedAt: t1, deleted: true, device: "m1")]
        let stale = SyncRecord(key: "snippet:a", modifiedAt: t0, deleted: false, payload: .string("old"), device: "m3")
        XCTAssertTrue(SyncMerge.incoming(remote: [stale], ledger: ledger, kinds: ["snippet"]).isEmpty)
    }
}

@MainActor
final class FolderSyncTests: XCTestCase {
    private var folder: URL!
    private var macs: [(sync: FolderSync, stack: CoreDataStack, defaults: UserDefaults, monitor: ClipboardMonitor)] = []

    override func setUp() async throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("clipflow-sync-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        macs = []
        for index in 0..<3 {
            let stack = CoreDataStack(storeURL: nil)
            let suite = "clipflow-tests-sync-mac\(index)-\(name.filter { $0.isLetter || $0.isNumber })"
            let defaults = makeTestDefaults(suite)
            AppDefaults.register(in: defaults)
            defaults.set(true, forKey: FolderSync.enabledKey)
            defaults.set(folder.appendingPathComponent("shared").path, forKey: FolderSync.folderKey)
            let monitor = ClipboardMonitor(context: stack.viewContext, pasteboard: NSPasteboard(name: .init("clipflow-tests")), defaults: defaults)
            let sync = FolderSync(ledgerDirectory: folder.appendingPathComponent("ledger\(index)"))
            let store = SyncStore(
                context: stack.viewContext, monitor: monitor, defaults: defaults,
                explicitSettings: { ["viewMode": defaults.string(forKey: "viewMode") ?? "organized"] }
            )
            sync.configure(store: store, defaults: defaults)
            macs.append((sync, stack, defaults, monitor))
        }
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: folder)
    }

    @discardableResult
    private func addSnippet(_ abbreviation: String, content: String, group: String, on mac: Int) throws -> Snippet {
        let context = macs[mac].stack.viewContext
        let existing = SnippetGroup.ordered(in: context).first { $0.name == group } ?? SnippetGroup.insert(named: group, in: context)
        let snippet = Snippet.insert(title: abbreviation, abbreviation: abbreviation, content: content, group: existing, in: context)
        try context.save()
        return snippet
    }

    private func snippets(on mac: Int) throws -> [String: String] {
        let all = try macs[mac].stack.viewContext.fetch(Snippet.fetchRequest())
        return Dictionary(all.map { ($0.abbreviation, $0.content) }, uniquingKeysWith: { [$0, $1].sorted().joined(separator: " | ") })
    }

    private func syncAll() async {
        for mac in macs { await mac.sync.sync() }
        for mac in macs { await mac.sync.sync() }
    }

    func testTwoMacsShareSnippetsEditsDeletionsAndPinsWithoutDuplicatingTheStarters() async throws {
        try addLegacyStarters(on: 0)
        try addSnippet(".hi", content: "Hello", group: "Personal", on: 0)
        try addLegacyStarters(on: 1)
        await syncAll()

        let expected = starterContents.merging([".hi": "Hello"]) { $1 }
        XCTAssertEqual(try snippets(on: 1), expected, "the starters of two old installs meet as the same snippets")
        XCTAssertEqual(try snippets(on: 0), expected)

        let hi = try XCTUnwrap(try macs[1].stack.viewContext.fetch(Snippet.fetchRequest()).first { $0.abbreviation == ".hi" })
        hi.content = "Hello there"
        try macs[1].stack.viewContext.save()
        await syncAll()
        XCTAssertEqual(try snippets(on: 0)[".hi"], "Hello there")

        let onA = try XCTUnwrap(try macs[0].stack.viewContext.fetch(Snippet.fetchRequest()).first { $0.abbreviation == ".hi" })
        macs[0].stack.viewContext.delete(onA)
        try macs[0].stack.viewContext.save()
        await syncAll()
        XCTAssertNil(try snippets(on: 1)[".hi"])

        macs[0].monitor.pinText("Account 1234")
        macs[0].defaults.set("simple", forKey: "viewMode")
        await syncAll()
        XCTAssertEqual(macs[1].monitor.pinnedTexts().map(\.content), ["Account 1234"])
        XCTAssertEqual(macs[1].defaults.string(forKey: "viewMode"), "simple")

        guard case .synced(_, let otherMacs) = macs[0].sync.status else { return XCTFail("expected a synced status") }
        XCTAssertEqual(otherMacs, 2)
    }

    private func deviceFiles() throws -> [String: Data] {
        let devices = folder.appendingPathComponent("shared/devices")
        var files: [String: Data] = [:]
        for name in try FileManager.default.contentsOfDirectory(atPath: devices.path) {
            files[name] = try Data(contentsOf: devices.appendingPathComponent(name))
        }
        return files
    }

    func testOnceInStepNothingIsRewrittenEvenForAPinnedRichTextClip() async throws {
        try addSnippet(".a", content: "A", group: "Work", on: 0)
        let rich = PasteboardSnapshot(items: [[
            NSPasteboard.PasteboardType.string.rawValue: Data("Bold note".utf8),
            NSPasteboard.PasteboardType.rtf.rawValue: Data("{\\rtf1 Bold note}".utf8)
        ]])
        macs[0].monitor.record(try XCTUnwrap(ClipCapture.classify(rich)), snapshot: rich, sourceName: nil, sourceBundleID: nil)
        let clip = try XCTUnwrap(macs[0].monitor.clipHistory.first { $0.content == "Bold note" })
        XCTAssertEqual(clip.kind, .rtf)
        macs[0].monitor.setPinned(clip, true)
        await syncAll()
        XCTAssertEqual(macs[1].monitor.pinnedTexts().map(\.content), ["Bold note"])

        let settled = try deviceFiles()
        await syncAll()
        await syncAll()
        XCTAssertEqual(try deviceFiles(), settled, "a pin stored as rich text on one Mac and plain on another is the same pin")
    }

    func testAnEditOnAThirdMacSurvivesAGroupDeletionItHasNotSeen() async throws {
        try addSnippet(".s", content: "v1", group: "G", on: 0)
        await syncAll()

        let contextA = macs[0].stack.viewContext
        let group = try XCTUnwrap(SnippetGroup.ordered(in: contextA).first { $0.name == "G" })
        for snippet in group.snippets { contextA.delete(snippet) }
        contextA.delete(group)
        try contextA.save()
        await macs[0].sync.sync()

        // C edits before the cloud has brought it A's deletion: A's file is out of the folder while C syncs.
        let devices = folder.appendingPathComponent("shared/devices")
        let aside = folder.appendingPathComponent("aside")
        try FileManager.default.createDirectory(at: aside, withIntermediateDirectories: true)
        let fileA = try XCTUnwrap(macs[0].sync.deviceFileName)
        try FileManager.default.moveItem(at: devices.appendingPathComponent(fileA), to: aside.appendingPathComponent(fileA))
        try await Task.sleep(nanoseconds: 5_000_000)
        let onC = try XCTUnwrap(try macs[2].stack.viewContext.fetch(Snippet.fetchRequest()).first { $0.abbreviation == ".s" })
        onC.content = "v2"
        try macs[2].stack.viewContext.save()
        await macs[2].sync.sync()
        try FileManager.default.moveItem(at: aside.appendingPathComponent(fileA), to: devices.appendingPathComponent(fileA))

        // B now sees A's deletion of the group and C's later edit of a snippet in it, at once.
        await macs[1].sync.sync()
        await syncAll()

        for mac in 0..<3 {
            XCTAssertEqual(try snippets(on: mac), [".s": "v2"], "Mac \(mac) keeps the later edit")
        }
    }

    private func layout(on mac: Int) throws -> [String] {
        try macs[mac].stack.viewContext.fetch(Snippet.fetchRequest())
            .map { "\($0.abbreviation) in \($0.group?.name ?? "no group")" }
            .sorted()
    }

    private let starterContents = Dictionary(uniqueKeysWithValues: StarterSnippets.all.map { ($0.abbreviation, $0.content) })

    /// The starters as an install from before the fixed ids created them: random ids.
    private func addLegacyStarters(on mac: Int) throws {
        let context = macs[mac].stack.viewContext
        let group = SnippetGroup.insert(named: SnippetLibraryRepair.starterGroupName, in: context)
        for starter in StarterSnippets.all {
            _ = Snippet.insert(title: starter.title, abbreviation: starter.abbreviation, content: starter.content, group: group, in: context)
        }
        try context.save()
    }

    func testANewMacJoiningLaterNeitherUndoesStarterEditsNorBringsBackDeletedOnes() async throws {
        macs[0].stack.prepareDefaultData(defaults: macs[0].defaults)
        await macs[0].sync.sync()
        let contextA = macs[0].stack.viewContext
        let sig = try XCTUnwrap(try contextA.fetch(Snippet.fetchRequest()).first { $0.abbreviation == ".sig" })
        sig.content = "Cheers,\nAriel"
        sig.updatedAt = Date()
        let dd = try XCTUnwrap(try contextA.fetch(Snippet.fetchRequest()).first { $0.abbreviation == ".dd" })
        contextA.delete(dd)
        try contextA.save()
        await macs[0].sync.sync()

        try await Task.sleep(nanoseconds: 5_000_000)
        macs[1].stack.prepareDefaultData(defaults: macs[1].defaults)
        await syncAll()

        for mac in 0..<2 {
            let all = try snippets(on: mac)
            XCTAssertEqual(all[".sig"], "Cheers,\nAriel", "Mac \(mac) keeps the edited signature")
            XCTAssertNil(all[".dd"], "Mac \(mac) does not get the deleted starter back")
        }
    }

    func testAnOldInstallWithItsOwnSnippetsInPersonalDoesNotUndoAStarterEdit() async throws {
        macs[1].stack.prepareDefaultData(defaults: macs[1].defaults)
        await macs[1].sync.sync()
        let contextB = macs[1].stack.viewContext
        let sig = try XCTUnwrap(try contextB.fetch(Snippet.fetchRequest()).first { $0.abbreviation == ".sig" })
        sig.content = "Cheers"
        sig.updatedAt = Date()
        try contextB.save()
        await macs[1].sync.sync()

        try await Task.sleep(nanoseconds: 5_000_000)
        try addLegacyStarters(on: 0)
        try addSnippet(".mine", content: "mine", group: SnippetLibraryRepair.starterGroupName, on: 0)
        await syncAll()

        for mac in 0..<2 {
            XCTAssertEqual(try snippets(on: mac)[".sig"], "Cheers", "Mac \(mac) keeps the earlier edit")
            XCTAssertEqual(try snippets(on: mac)[".mine"], "mine")
        }
    }

    func testTheUsersOwnPersonalGroupIsNotTiedToTheStarterGroup() async throws {
        try addLegacyStarters(on: 1)
        try addSnippet(".mine", content: "mine", group: SnippetLibraryRepair.starterGroupName, on: 1)
        try await Task.sleep(nanoseconds: 5_000_000)

        macs[0].stack.prepareDefaultData(defaults: macs[0].defaults)
        await macs[0].sync.sync()
        let contextA = macs[0].stack.viewContext
        let starterGroup = try XCTUnwrap(SnippetGroup.ordered(in: contextA).first)
        for snippet in starterGroup.snippets { contextA.delete(snippet) }
        contextA.delete(starterGroup)
        try contextA.save()
        await macs[0].sync.sync()
        await syncAll()

        for mac in 0..<2 {
            XCTAssertEqual(try layout(on: mac), [".mine in Personal"], "Mac \(mac): the deleted starters stay deleted, the user's group stays")
        }
    }

    func testAMacJoiningLaterMeetsTheSameStarters() async throws {
        try addLegacyStarters(on: 0)
        try addLegacyStarters(on: 1)
        for _ in 0..<2 { for mac in 0..<2 { await macs[mac].sync.sync() } }
        try addLegacyStarters(on: 2)
        await syncAll()

        let expected = StarterSnippets.all.map { "\($0.abbreviation) in Personal" }.sorted()
        for mac in 0..<3 {
            XCTAssertEqual(try layout(on: mac), expected, "Mac \(mac)")
            XCTAssertEqual(SnippetGroup.ordered(in: macs[mac].stack.viewContext).map(\.name), ["Personal"], "Mac \(mac)")
        }
    }

    func testTwoSnippetsMadeAlikeOnTwoMacsAreBothKept() async throws {
        try addSnippet(".addr", content: "Home", group: "Mine", on: 0)
        try addSnippet(".addr", content: "Home", group: "Mine", on: 1)
        await syncAll()
        XCTAssertEqual(try snippets(on: 0), [".addr": "Home | Home"], "nothing is merged by guess; the user removes the copy they do not want")
    }

    func testJoiningAFolderAgainKeepsAnEditMadeSince() async throws {
        let snippet = try addSnippet(".s", content: "old", group: "G", on: 0)
        await syncAll()
        try await Task.sleep(nanoseconds: 5_000_000)
        snippet.content = "edited while away"
        snippet.updatedAt = Date()
        try macs[0].stack.viewContext.save()
        macs[0].sync.reset()
        await syncAll()
        XCTAssertEqual(try snippets(on: 1)[".s"], "edited while away")
        XCTAssertEqual(try snippets(on: 0)[".s"], "edited while away")
    }

    func testDeletingAGroupKeepsASnippetEditedSinceOnTheOtherMac() async throws {
        try addSnippet(".a", content: "A", group: "Work", on: 0)
        try addSnippet(".b", content: "B", group: "Work", on: 0)
        await syncAll()

        let contextA = macs[0].stack.viewContext
        let work = try XCTUnwrap(SnippetGroup.ordered(in: contextA).first { $0.name == "Work" })
        for snippet in work.snippets { contextA.delete(snippet) }
        contextA.delete(work)
        try contextA.save()
        await macs[0].sync.sync()

        try await Task.sleep(nanoseconds: 5_000_000)
        let onB = try XCTUnwrap(try macs[1].stack.viewContext.fetch(Snippet.fetchRequest()).first { $0.abbreviation == ".b" })
        onB.content = "B edited later"
        try macs[1].stack.viewContext.save()
        await syncAll()

        XCTAssertEqual(try snippets(on: 1), [".b": "B edited later"], ".a goes with the group, the later edit of .b stays")
        XCTAssertEqual(try snippets(on: 0), [".b": "B edited later"])
        XCTAssertTrue(SnippetGroup.ordered(in: macs[1].stack.viewContext).isEmpty)
    }

    func testAConflictCopyMadeByTheCloudIsNotAnotherMac() async throws {
        try addSnippet(".a", content: "A", group: "Work", on: 0)
        await macs[0].sync.sync()
        let devices = folder.appendingPathComponent("shared/devices")
        let own = try XCTUnwrap(try FileManager.default.contentsOfDirectory(atPath: devices.path).first)
        try FileManager.default.copyItem(at: devices.appendingPathComponent(own), to: devices.appendingPathComponent("conflict 2.json"))
        await macs[1].sync.sync()
        guard case .synced(_, let otherMacs) = macs[1].sync.status else { return XCTFail("expected a synced status") }
        XCTAssertEqual(otherMacs, 1)
    }
}

final class TextRecognizerTests: XCTestCase {
    private let supported = ["en-US", "fr-FR", "ar-SA", "ru-RU"]

    func testLanguagesFollowTheSavedChoiceElseTheUsersLanguagesThenEnglish() {
        XCTAssertEqual(TextRecognizer.languages(saved: ["ru-RU"], preferred: ["he-IL"], supported: supported), ["ru-RU"])
        XCTAssertEqual(TextRecognizer.languages(saved: ["he-IL"], preferred: ["fr-CA", "he-IL"], supported: supported), ["fr-FR", "en-US"],
                       "a saved language the system dropped falls back")
        XCTAssertEqual(TextRecognizer.languages(saved: [], preferred: ["he-IL", "en-IL"], supported: supported), ["en-US"],
                       "Hebrew is skipped until the system supports it")
        XCTAssertEqual(TextRecognizer.languages(saved: [], preferred: ["he-IL"], supported: supported + ["he-IL"]), ["he-IL", "en-US"],
                       "once supported, Hebrew is picked up with no update")
    }

    func testRecognizesTextInARenderedImage() async throws {
        let image = NSImage(size: NSSize(width: 520, height: 120), flipped: false) { rect in
            NSColor.white.setFill()
            rect.fill()
            NSAttributedString(string: "Invoice 4821 paid", attributes: [.font: NSFont.systemFont(ofSize: 44), .foregroundColor: NSColor.black])
                .draw(at: NSPoint(x: 20, y: 35))
            return true
        }
        let png = try XCTUnwrap(NSBitmapImageRep(data: try XCTUnwrap(image.tiffRepresentation))?.representation(using: .png, properties: [:]))
        let text = await TextRecognizer.recognize(imageData: png, languages: ["en-US"])
        XCTAssertEqual(text, "Invoice 4821 paid")
        let notAnImage = await TextRecognizer.recognize(imageData: Data("text".utf8), languages: ["en-US"])
        XCTAssertNil(notAnImage)
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

final class SensitiveTextTests: XCTestCase {
    func testOneTimeCodes() {
        for code in ["482913", "482 913", "482-913", "G-482913", " 482913\n"] {
            XCTAssertEqual(SensitiveText.kind(of: code), .oneTimeCode, code)
        }
        for text in ["2026", "12345", "6100000", "20261121", "123-4567", "123456789", "code 482913", "48 2913"] {
            XCTAssertNil(SensitiveText.kind(of: text), text)
        }
    }

    func testCardNumbersNeedTheLuhnCheckAndACardPrefix() {
        XCTAssertEqual(SensitiveText.kind(of: "4242 4242 4242 4242"), .cardNumber)
        XCTAssertEqual(SensitiveText.kind(of: "5555-5555-5555-4444"), .cardNumber)
        XCTAssertEqual(SensitiveText.kind(of: "378282246310005"), .cardNumber)
        XCTAssertNil(SensitiveText.kind(of: "4242424242424241"), "fails Luhn")
        XCTAssertNil(SensitiveText.kind(of: "1234567812345670"), "passes Luhn, no card starts with 1")
        XCTAssertNil(SensitiveText.kind(of: "4242  4242 4242 4242"), "two spaces in a row")
        XCTAssertNil(SensitiveText.kind(of: "352099001761481"), "a Luhn-valid IMEI")
        XCTAssertEqual(SensitiveText.kind(of: "4242\u{00A0}4242\u{00A0}4242\u{00A0}4242"), .cardNumber)
    }

    func testIBANsNeedTheMod97Check() {
        XCTAssertEqual(SensitiveText.kind(of: "IL62 0108 0000 0009 9999 999"), .iban)
        XCTAssertEqual(SensitiveText.kind(of: "gb82west12345698765432"), .iban)
        XCTAssertEqual(SensitiveText.kind(of: "IL62\u{00A0}0108\u{00A0}0000\u{00A0}0009\u{00A0}9999\u{00A0}999"), .iban)
        XCTAssertNil(SensitiveText.kind(of: "GB82 WEST 1234 5698 7654 33"))
        XCTAssertNil(SensitiveText.kind(of: "Pay to IL620108000000099999999"))
    }
}

@MainActor
final class SensitiveClipTests: XCTestCase {
    private var stack: CoreDataStack!
    private var defaults: UserDefaults!
    private var pasteboard: NSPasteboard!
    private var monitor: ClipboardMonitor!

    override func setUp() async throws {
        stack = CoreDataStack(storeURL: nil)
        defaults = makeTestDefaults("clipflow-tests-sensitive")
        AppDefaults.register(in: defaults)
        pasteboard = NSPasteboard(name: .init("clipflow-tests-sensitive"))
        monitor = ClipboardMonitor(context: stack.viewContext, pasteboard: pasteboard, defaults: defaults)
        monitor.startMonitoring()
    }

    override func tearDown() async throws {
        monitor.stopMonitoring()
        pasteboard.releaseGlobally()
    }

    private func copy(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        monitor.checkPasteboard()
    }

    private var history: [String] { monitor.clipHistory.map(\.content) }

    func testACodeIsRemovedOnceItsTimeIsUpAndOtherClipsStay() {
        copy("hello")
        copy("482913")
        XCTAssertEqual(history, ["482913", "hello"])
        monitor.removeExpiredSensitiveClips(now: Date().addingTimeInterval(4 * 60))
        XCTAssertEqual(history, ["482913", "hello"])
        monitor.removeExpiredSensitiveClips(now: Date().addingTimeInterval(5 * 60 + 1))
        XCTAssertEqual(history, ["hello"])
        XCTAssertEqual(pasteboard.string(forType: .string), "482913", "the clipboard is left alone by default")
    }

    func testDontSaveSkipsTheCopyAndKeepRecordsIt() {
        defaults.set(SensitiveHandling.skip.rawValue, forKey: SensitiveText.handlingKey)
        copy("4242 4242 4242 4242")
        XCTAssertEqual(history, [])
        defaults.set(SensitiveHandling.keep.rawValue, forKey: SensitiveText.handlingKey)
        copy("IL62 0108 0000 0009 9999 999")
        defaults.set(SensitiveHandling.expire.rawValue, forKey: SensitiveText.handlingKey)
        monitor.removeExpiredSensitiveClips(now: Date().addingTimeInterval(24 * 3600))
        XCTAssertEqual(history, ["IL62 0108 0000 0009 9999 999"], "kept while Keep was on, so never scheduled")
    }

    func testTextClipFlowPutsOnTheClipboardIsCheckedToo() {
        defaults.set(SensitiveHandling.skip.rawValue, forKey: SensitiveText.handlingKey)
        monitor.copy("482913")
        XCTAssertEqual(history, [])
        XCTAssertEqual(pasteboard.string(forType: .string), "482913")
    }

    func testSwitchingToDontSaveRemovesWaitingCodesAtOnce() {
        defaults.set(true, forKey: SensitiveText.clearClipboardKey)
        copy("482913")
        defaults.set(SensitiveHandling.skip.rawValue, forKey: SensitiveText.handlingKey)
        monitor.removeExpiredSensitiveClips()
        XCTAssertEqual(history, [])
        XCTAssertEqual(pasteboard.string(forType: .string), "482913", "the clipboard option belongs to Remove later only")
    }

    func testAKindThatIsNotDetectedIsKept() {
        defaults.set(false, forKey: SensitiveKind.oneTimeCode.defaultsKey)
        copy("482913")
        monitor.removeExpiredSensitiveClips(now: Date().addingTimeInterval(3600))
        XCTAssertEqual(history, ["482913"])
    }

    func testAPinnedCodeIsKept() {
        copy("482913")
        monitor.setPinned(monitor.clipHistory[0], true)
        monitor.removeExpiredSensitiveClips(now: Date().addingTimeInterval(3600))
        XCTAssertEqual(history, ["482913"])
    }

    func testTheClipboardIsEmptiedOnlyWhileItStillHoldsTheCode() {
        defaults.set(true, forKey: SensitiveText.clearClipboardKey)
        copy("482913")
        monitor.removeExpiredSensitiveClips(now: Date().addingTimeInterval(3600))
        XCTAssertNil(pasteboard.string(forType: .string))

        copy("553311")
        pasteboard.clearContents()
        pasteboard.setString("553311", forType: .string)
        monitor.removeExpiredSensitiveClips(now: Date().addingTimeInterval(3600))
        XCTAssertNil(pasteboard.string(forType: .string), "picked again from history, so still the same code")

        copy("661122")
        copy("later text")
        monitor.removeExpiredSensitiveClips(now: Date().addingTimeInterval(3600))
        XCTAssertEqual(history, ["later text"])
        XCTAssertEqual(pasteboard.string(forType: .string), "later text")
    }

    func testARelaunchRemovesOnlyTheClipsThatWereWaiting() {
        let old = PasteboardSnapshot.text("482913", transient: false)
        monitor.record(ClipCapture.classify(old)!, snapshot: old, sourceName: nil, sourceBundleID: nil, at: Date().addingTimeInterval(-600))
        copy("553311")
        monitor.scheduleRemoval(of: monitor.clipHistory.first { $0.content == "553311" }!.id, copiedAt: Date().addingTimeInterval(-600))
        copy("661122")

        let relaunched = ClipboardMonitor(context: stack.viewContext, pasteboard: pasteboard, defaults: defaults)
        XCTAssertEqual(relaunched.clipHistory.map(\.content), ["661122", "482913"], "history that was never scheduled stays")
        relaunched.removeExpiredSensitiveClips(now: Date().addingTimeInterval(5 * 60 + 1))
        XCTAssertEqual(relaunched.clipHistory.map(\.content), ["482913"])
    }

    func testAFreshCopyOfTheSameCodeKeepsTheClipboardUntilItsOwnTime() {
        defaults.set(false, forKey: "removeDuplicates")
        defaults.set(true, forKey: SensitiveText.clearClipboardKey)
        copy("482913")
        let first = monitor.clipHistory[0].id
        monitor.scheduleRemoval(of: first, copiedAt: Date().addingTimeInterval(-290))
        copy("482913")
        monitor.removeExpiredSensitiveClips(now: Date().addingTimeInterval(15))
        XCTAssertEqual(history, ["482913"])
        XCTAssertNotEqual(monitor.clipHistory[0].id, first)
        XCTAssertEqual(pasteboard.string(forType: .string), "482913")
    }

    func testAPinnedCopyDoesNotHoldTheClipboard() {
        defaults.set(false, forKey: "removeDuplicates")
        defaults.set(true, forKey: SensitiveText.clearClipboardKey)
        copy("482913")
        monitor.scheduleRemoval(of: monitor.clipHistory[0].id, copiedAt: Date().addingTimeInterval(-290))
        copy("482913")
        monitor.setPinned(monitor.clipHistory[0], true)
        monitor.removeExpiredSensitiveClips(now: Date().addingTimeInterval(15))
        XCTAssertNil(pasteboard.string(forType: .string))
        XCTAssertEqual(history, ["482913"])
    }
}
