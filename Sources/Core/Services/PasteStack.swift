import AppKit

/// Copies collected while the stack is on, pasted one at a time with the "Paste next" shortcut. Kept in memory only.
@MainActor
final class PasteStack: ObservableObject {
    static let shared = PasteStack()

    nonisolated static let orderKey = "pasteStackOrder"
    nonisolated static let endsWhenEmptyKey = "pasteStackEndsWhenEmpty"

    enum Order: String, CaseIterable {
        /// The first copy is pasted first.
        case copied
        /// The last copy is pasted first.
        case reversed
    }

    struct Item: Identifiable, Equatable {
        let id = UUID()
        let snapshot: PasteboardSnapshot
        let preview: String
    }

    @Published private(set) var isOn = false
    /// In copy order, whatever the paste order.
    @Published private(set) var items: [Item] = []

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var order: Order { Order(rawValue: defaults.string(forKey: Self.orderKey) ?? "") ?? .copied }
    var endsWhenEmpty: Bool { defaults.bool(forKey: Self.endsWhenEmptyKey) }

    func toggle() {
        isOn ? end() : start()
    }

    func start() {
        items.removeAll()
        isOn = true
    }

    func end() {
        items.removeAll()
        isOn = false
    }

    func add(_ snapshot: PasteboardSnapshot, preview: String) {
        guard isOn else { return }
        items.append(Item(snapshot: snapshot, preview: preview))
    }

    func remove(_ id: Item.ID) {
        items.removeAll { $0.id == id }
    }

    /// The item to paste now, removed from the stack; the stack ends after its last item when set to.
    func takeNext() -> Item? {
        guard isOn, !items.isEmpty else { return nil }
        let item = order == .copied ? items.removeFirst() : items.removeLast()
        if items.isEmpty, endsWhenEmpty { isOn = false }
        return item
    }

    /// The item "Paste next" would paste.
    var upNext: Item? { order == .copied ? items.first : items.last }

    /// Pastes the next item into the frontmost app; it stays on the clipboard, as if just copied.
    func pasteNext() async {
        guard await SyntheticKeyboard.modifiersReleased(), let item = takeNext() else {
            NSSound.beep()
            return
        }
        await PasteEngine.shared.paste(item.snapshot, into: nil)
    }
}
