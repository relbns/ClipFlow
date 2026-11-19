import AppKit
import CoreData
import XCTest
@testable import ClipFlow

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
        let known = [1, 2].contains { NSManagedObjectModel.clipFlowModel(version: $0, bindClasses: false).isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata) }
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

    func testStoreFromANewerVersionIsLeftUntouched() throws {
        let storeURL = directory.appendingPathComponent("ClipFlow.sqlite")
        let newer = NSManagedObjectModel.clipFlowModel(version: 2, bindClasses: false)
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
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "clipflow-test-\(UUID().uuidString)"))

        stack.prepareDefaultData(defaults: defaults)
        stack.prepareDefaultData(defaults: UserDefaults(suiteName: "clipflow-test-\(UUID().uuidString)")!)

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
    func testArrowsMoveWithinTheNumberedClipsAndDigitsOnlyWorkWithAnEmptySearch() {
        let stack = CoreDataStack(storeURL: nil)
        let monitor = ClipboardMonitor(context: stack.viewContext)
        for index in 1...12 {
            let snapshot = PasteboardSnapshot.text("clip \(index)", transient: false)
            monitor.record(ClipCapture.classify(snapshot)!, snapshot: snapshot, source: nil)
        }

        let navigation = PopoverNavigation.shared
        navigation.clipboardMonitor = monitor
        navigation.searchText = ""
        XCTAssertEqual(navigation.navigableClips.count, 10)
        XCTAssertEqual(navigation.selectedID, navigation.navigableClips[0].id)

        XCTAssertTrue(navigation.handle(.init(keyCode: 126)))
        XCTAssertEqual(navigation.selectedID, navigation.navigableClips[0].id)
        for _ in 0..<15 { _ = navigation.handle(.init(keyCode: 125)) }
        XCTAssertEqual(navigation.selectedID, navigation.navigableClips[9].id)

        XCTAssertFalse(navigation.handle(.init(keyCode: 125, hasModifiers: true)))
        XCTAssertTrue(navigation.handle(.init(keyCode: 18, characters: "1")))

        navigation.searchText = "clip 1"
        XCTAssertEqual(navigation.selectedID, navigation.navigableClips[0].id)
        XCTAssertFalse(navigation.handle(.init(keyCode: 18, characters: "1")))
        XCTAssertFalse(navigation.handle(.init(keyCode: 0, characters: "a")))
        navigation.clipboardMonitor = nil
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
