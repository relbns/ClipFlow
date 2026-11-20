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
    static func stamp(
        local: [String: JSONValue], ledger: [String: SyncLedgerEntry], kinds: Set<String>, now: Date, device: String
    ) -> [String: SyncLedgerEntry] {
        var result = ledger
        for (key, payload) in local {
            let hash = payload.stableHash
            if let entry = ledger[key], !entry.deleted, entry.hash == hash { continue }
            result[key] = SyncLedgerEntry(hash: hash, modifiedAt: after(ledger[key], now), deleted: false, device: device)
        }
        for (key, entry) in ledger where !entry.deleted && local[key] == nil && kinds.contains(kind(of: key)) {
            result[key] = SyncLedgerEntry(hash: "", modifiedAt: after(entry, now), deleted: true, device: device)
        }
        return result
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

    /// When a Mac syncs for the first time, its own snippets that another Mac already has, with the same
    /// abbreviation and the same text (the starter snippets, or a snippet set up twice), are the same snippets and
    /// are dropped here; a snippet with the same abbreviation but other text is kept. Groups with the same name fold
    /// into the other Mac's group. Only each key's newest remote record counts, so a stale file cannot match.
    static func firstJoin(local: [String: JSONValue], remote: [SyncRecord]) -> (dropSnippets: Set<String>, groupMap: [String: String]) {
        var newest: [String: SyncRecord] = [:]
        for record in remote {
            if let current = newest[record.key], !isNewer(record, than: current.modifiedAt, current.device) { continue }
            newest[record.key] = record
        }
        let live = newest.values.filter { !$0.deleted }
        func signature(_ payload: JSONValue?) -> String? {
            guard let abbreviation = payload?["abbreviation"]?.string?.lowercased() else { return nil }
            return abbreviation + "\u{0}" + (payload?["content"]?.string ?? "")
        }
        let remoteSnippets = Set(live.filter { $0.kind == "snippet" }.compactMap { signature($0.payload) })
        var remoteGroups: [String: String] = [:]
        for record in live where record.kind == "group" {
            if let name = record.payload?["name"]?.string { remoteGroups[name] = id(of: record.key) }
        }
        var drop: Set<String> = []
        var groupMap: [String: String] = [:]
        for (key, payload) in local where newest[key] == nil {
            switch kind(of: key) {
            case "snippet":
                if let signature = signature(payload), remoteSnippets.contains(signature) {
                    drop.insert(key)
                }
            case "group":
                if let name = payload["name"]?.string, let remoteID = remoteGroups[name], remoteID != id(of: key) {
                    groupMap[id(of: key)] = remoteID
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
