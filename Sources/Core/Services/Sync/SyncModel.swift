import CryptoKit
import Foundation

/// A JSON value, so a synced record carries any snippet, group, pin or setting.
enum JSONValue: Codable, Equatable, Hashable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([JSONValue].self) { self = .array(value) }
        else { self = .object(try container.decode([String: JSONValue].self)) }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    subscript(key: String) -> JSONValue? {
        if case .object(let object) = self { return object[key] }
        return nil
    }

    var string: String? { if case .string(let value) = self { return value }; return nil }
    var bool: Bool? { if case .bool(let value) = self { return value }; return nil }
    var number: Double? { if case .number(let value) = self { return value }; return nil }

    /// The same for equal values on every Mac: keys sorted, no whitespace.
    var stableHash: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = (try? encoder.encode(self)) ?? Data()
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

/// One snippet, group, pin or setting as a Mac last saw it. Keys are "<kind>:<id>".
struct SyncRecord: Codable, Equatable {
    var key: String
    var modifiedAt: Date
    var deleted: Bool
    var payload: JSONValue?
    var device: String

    var kind: String { String(key.prefix { $0 != ":" }) }
}

/// What one Mac writes to the sync folder; each Mac writes only its own file, so cloud folders never hold
/// conflicting copies of it.
struct SyncDeviceFile: Codable {
    var version = 1
    var deviceID: String
    var deviceName: String
    var writtenAt: Date
    /// The Mac has once synced with the other Macs' files present; a Mac joining later yields to its copies.
    var joined: Bool?
    var records: [SyncRecord]
}

/// What this Mac last synced of each record, so a local edit or deletion is told apart from an old state.
struct SyncLedgerEntry: Codable, Equatable {
    var hash: String
    var modifiedAt: Date
    var deleted: Bool
    var device: String
}

enum SyncMerge {
    /// Stamps local edits and deletions with `now`. Only records of `kinds` can be deleted, so turning off a
    /// kind (say settings) does not delete it on the other Macs.
    /// `skip` holds keys whose remote change could not be applied yet; they are left for the next pass.
    static func stamp(
        local: [String: JSONValue], ledger: [String: SyncLedgerEntry], kinds: Set<String>, now: Date, device: String,
        skip: Set<String> = []
    ) -> [String: SyncLedgerEntry] {
        var result = ledger
        for (key, payload) in local where !skip.contains(key) {
            let hash = payload.stableHash
            if let entry = ledger[key], !entry.deleted, entry.hash == hash { continue }
            result[key] = SyncLedgerEntry(hash: hash, modifiedAt: after(ledger[key], now), deleted: false, device: device)
        }
        for (key, entry) in ledger where !entry.deleted && local[key] == nil && kinds.contains(kind(of: key)) && !skip.contains(key) {
            result[key] = SyncLedgerEntry(hash: "", modifiedAt: after(entry, now), deleted: true, device: device)
        }
        return result
    }

    /// Each key's newest record across the other Macs' files.
    static func newest(_ remote: [SyncRecord]) -> [String: SyncRecord] {
        var newest: [String: SyncRecord] = [:]
        for record in remote {
            if let current = newest[record.key], !isNewer(record, than: current.modifiedAt, current.device) { continue }
            newest[record.key] = record
        }
        return newest
    }

    /// Groups whose latest known state, here or on another Mac, is deleted.
    static func deletedGroups(remote: [SyncRecord], ledger: [String: SyncLedgerEntry]) -> Set<String> {
        var deleted: Set<String> = []
        for (key, record) in newest(remote) where kind(of: key) == "group" && record.deleted {
            if let entry = ledger[key], !isNewer(record, than: entry.modifiedAt, entry.device) { continue }
            deleted.insert(id(of: key))
        }
        for (key, entry) in ledger where kind(of: key) == "group" && entry.deleted {
            deleted.insert(id(of: key))
        }
        return deleted
    }

    /// A local change is always newer than the version it replaces, even when another Mac's clock runs ahead.
    private static func after(_ entry: SyncLedgerEntry?, _ now: Date) -> Date {
        guard let entry, entry.modifiedAt != .distantPast else { return now }
        return max(now, entry.modifiedAt.addingTimeInterval(0.001))
    }

    /// Remote records newer than this Mac's; equal times go to the larger device id, the same choice on every Mac.
    static func incoming(remote: [SyncRecord], ledger: [String: SyncLedgerEntry], kinds: Set<String>) -> [SyncRecord] {
        var newest: [String: SyncRecord] = [:]
        for record in remote where kinds.contains(record.kind) {
            if let current = newest[record.key], !isNewer(record, than: current.modifiedAt, current.device) { continue }
            newest[record.key] = record
        }
        return newest.values
            .filter { record in
                guard let entry = ledger[record.key] else { return !record.deleted }
                guard isNewer(record, than: entry.modifiedAt, entry.device) else { return false }
                return record.deleted ? !entry.deleted : record.payload?.stableHash != entry.hash || entry.deleted
            }
            .sorted { $0.key < $1.key }
    }

    /// Run while a Mac joins a folder: the same snippet set up on two Macs (the starter snippets, or one typed on
    /// both) arrives under two ids. Every Mac keeps the copy with the smaller id, so they agree whatever order they
    /// join in. Copies count as the same only when everything matches (title, abbreviation, text, trigger, options,
    /// app rules and the group's name). A group folds into another Mac's group of the same name. Only another Mac's
    /// copy can replace one here; two of this Mac's own are never touched, and a record this Mac already deleted
    /// does not count, however stale another Mac's file is.
    /// `joinedDevices` are Macs that have joined already: a joining Mac yields to their copies whatever the ids, so
    /// a Mac joining late folds into what the others settled on; between Macs still joining, the smaller id wins.
    static func duplicates(
        local: [String: JSONValue], remote: [SyncRecord], ledger: [String: SyncLedgerEntry], joinedDevices: Set<String> = []
    ) -> (dropSnippets: Set<String>, groupMap: [String: String]) {
        // Another Mac's live copies, with the Mac each comes from; one this Mac already deleted does not count.
        var remoteLive: [String: (payload: JSONValue, device: String)] = [:]
        for (key, record) in newest(remote) where !record.deleted {
            if let entry = ledger[key], entry.deleted, !isNewer(record, than: entry.modifiedAt, entry.device) { continue }
            if let payload = record.payload { remoteLive[key] = (payload, record.device) }
        }
        func origin(_ key: String) -> String { remoteLive[key]?.device ?? "\u{0}this Mac" }

        var groupNames: [String: String] = [:]
        for (key, payload) in remoteLive.mapValues(\.payload).merging(local, uniquingKeysWith: { _, mine in mine })
        where kind(of: key) == "group" {
            groupNames[id(of: key)] = payload["name"]?.string
        }
        func signature(_ payload: JSONValue) -> String? {
            guard case .object(var fields) = payload else { return nil }
            fields["group"] = payload["group"]?.string.flatMap { groupNames[$0] }.map(JSONValue.string) ?? .null
            return JSONValue.object(fields).stableHash
        }

        var snippetCopies: [String: [(key: String, device: String)]] = [:]
        var groupCopies: [String: [(key: String, device: String)]] = [:]
        for (key, entry) in remoteLive {
            switch kind(of: key) {
            case "snippet": if let signature = signature(entry.payload) { snippetCopies[signature, default: []].append((key, entry.device)) }
            case "group": if let name = entry.payload["name"]?.string { groupCopies[name, default: []].append((key, entry.device)) }
            default: break
            }
        }
        /// The copy `key` yields to, among copies from a Mac other than `key`'s own: one from a joined Mac when `key`'s
        /// own Mac has not joined, else the smallest key when it is smaller than `key` and as settled.
        func keeper(for key: String, among copies: [(key: String, device: String)]?) -> String? {
            let mine = origin(key)
            let mineJoined = joinedDevices.contains(mine)
            let others = copies?.filter { $0.device != mine } ?? []
            if !mineJoined, let settled = others.filter({ joinedDevices.contains($0.device) }).map(\.key).min() {
                return settled
            }
            return others.filter { joinedDevices.contains($0.device) == mineJoined && $0.key < key }.map(\.key).min()
        }

        var drop: Set<String> = []
        var groupMap: [String: String] = [:]
        for (key, payload) in local {
            switch kind(of: key) {
            case "snippet":
                if let signature = signature(payload), keeper(for: key, among: snippetCopies[signature]) != nil { drop.insert(key) }
            case "group":
                if let name = payload["name"]?.string, let keep = keeper(for: key, among: groupCopies[name]) {
                    groupMap[id(of: key)] = id(of: keep)
                }
            default:
                break
            }
        }
        return (drop, groupMap)
    }

    /// The records this Mac publishes: every ledger entry, with the current payload for live ones.
    static func records(ledger: [String: SyncLedgerEntry], local: [String: JSONValue]) -> [SyncRecord] {
        ledger.compactMap { key, entry in
            if entry.deleted {
                return SyncRecord(key: key, modifiedAt: entry.modifiedAt, deleted: true, payload: nil, device: entry.device)
            }
            guard let payload = local[key] else { return nil }
            return SyncRecord(key: key, modifiedAt: entry.modifiedAt, deleted: false, payload: payload, device: entry.device)
        }
        .sorted { $0.key < $1.key }
    }

    static func kind(of key: String) -> String { String(key.prefix { $0 != ":" }) }
    static func id(of key: String) -> String { String(key.drop { $0 != ":" }.dropFirst()) }

    private static func isNewer(_ record: SyncRecord, than date: Date, _ device: String) -> Bool {
        record.modifiedAt > date || (record.modifiedAt == date && record.device > device)
    }
}
