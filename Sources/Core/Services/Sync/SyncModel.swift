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

    /// What a shared group's folder carries: the group by name only, since its order and on/off switch stay each
    /// person's own, and the snippets filed in it. A snippet moved out drops from this set and is deleted for the others.
    static func scoped(_ local: [String: JSONValue], toGroup groupID: String) -> [String: JSONValue] {
        var result: [String: JSONValue] = [:]
        if let name = local["group:\(groupID)"]?["name"] {
            result["group:\(groupID)"] = .object(["name": name])
        }
        for (key, payload) in local where kind(of: key) == "snippet" && payload["group"]?.string == groupID {
            result[key] = payload
        }
        return result
    }

    /// Remote records that belong to the shared group: its group record and its snippets. A deletion carries no
    /// group, so it counts only for a snippet this Mac knows to be in the group.
    static func inScope(_ remote: [SyncRecord], group groupID: String, known: Set<String>) -> [SyncRecord] {
        remote.filter { record in
            switch kind(of: record.key) {
            case "group": return id(of: record.key) == groupID
            case "snippet": return record.deleted ? known.contains(record.key) : record.payload?["group"]?.string == groupID
            default: return false
            }
        }
    }

    /// The one live group a shared folder holds, for a Mac that joins it; nil while it has none or holds several.
    static func sharedGroupID(in remote: [SyncRecord]) -> (id: String?, several: Bool) {
        let ids = Set(remote.filter { kind(of: $0.key) == "group" && !$0.deleted }.map { id(of: $0.key) })
        return (ids.count == 1 ? ids.first : nil, ids.count > 1)
    }

    static func kind(of key: String) -> String { String(key.prefix { $0 != ":" }) }
    static func id(of key: String) -> String { String(key.drop { $0 != ":" }.dropFirst()) }

    private static func isNewer(_ record: SyncRecord, than date: Date, _ device: String) -> Bool {
        record.modifiedAt > date || (record.modifiedAt == date && record.device > device)
    }
}
