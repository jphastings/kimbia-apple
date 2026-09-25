import Foundation

/// What has been synced for one account, kept on the device.
///
/// The ledger is what stops an activity being uploaded twice and what lets
/// the app list, and remove, the records it has written. Record keys are
/// derived from the activity itself (see `TID.stable`), so even a lost
/// ledger only means an activity is overwritten with itself, never duplicated.
public struct SyncLedger: Codable, Equatable, Sendable {
    /// Activities ending after this moment are synced automatically when
    /// they match the filter. `nil` until the person has finished setting
    /// up, so nothing is uploaded before they have chosen what to import.
    public var autoSyncFrom: Date?
    /// Everything this app has written, by HealthKit workout UUID.
    public var synced: [UUID: SyncedActivity]
    /// Activities the person removed from their PDS. Automatic syncing
    /// leaves these alone; they can still be imported again by hand.
    public var removed: Set<UUID>

    public init(autoSyncFrom: Date? = nil, synced: [UUID: SyncedActivity] = [:], removed: Set<UUID> = []) {
        self.autoSyncFrom = autoSyncFrom
        self.synced = synced
        self.removed = removed
    }

    public var isSetUp: Bool { autoSyncFrom != nil }

    public func contains(_ workoutID: UUID) -> Bool {
        synced[workoutID] != nil
    }
}

/// One activity this app has written to the PDS.
public struct SyncedActivity: Codable, Equatable, Hashable, Sendable {
    public let workoutID: UUID
    public let activityType: ActivityType
    public let start: Date
    public let collection: String
    public let rkey: String
    public let uri: String
    public let syncedAt: Date

    public init(workoutID: UUID, activityType: ActivityType, start: Date, collection: String, rkey: String, uri: String, syncedAt: Date) {
        self.workoutID = workoutID
        self.activityType = activityType
        self.start = start
        self.collection = collection
        self.rkey = rkey
        self.uri = uri
        self.syncedAt = syncedAt
    }
}

/// Persists a `SyncLedger` per account.
public protocol SyncLedgerStore: Sendable {
    func load(for did: String) throws -> SyncLedger
    func save(_ ledger: SyncLedger, for did: String) throws
    func clear(for did: String) throws
}

/// Keeps each account's ledger as a JSON file in `directory`.
///
/// Files are written with `completeUntilFirstUserAuthentication`
/// protection, as the Keychain item is, because background syncs can run
/// while the device is locked.
public final class FileSyncLedgerStore: SyncLedgerStore {
    private let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public func load(for did: String) throws -> SyncLedger {
        let url = fileURL(for: did)
        guard FileManager.default.fileExists(atPath: url.path) else { return SyncLedger() }
        return try Self.decoder.decode(SyncLedger.self, from: Data(contentsOf: url))
    }

    public func save(_ ledger: SyncLedger, for did: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try Self.encoder.encode(ledger)
        #if os(iOS)
        try data.write(to: fileURL(for: did), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: fileURL(for: did), options: .atomic)
        #endif
    }

    public func clear(for did: String) throws {
        let url = fileURL(for: did)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    /// DIDs contain colons, which are awkward in file names.
    private func fileURL(for did: String) -> URL {
        let safe = did.map { $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" ? $0 : "_" }
        return directory.appendingPathComponent(String(safe) + ".json")
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .sortedKeys
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

/// A ledger store that forgets everything when the process exits. For tests
/// and previews.
public final class InMemorySyncLedgerStore: SyncLedgerStore, @unchecked Sendable {
    private let lock = NSLock()
    private var ledgers: [String: SyncLedger] = [:]

    public init(_ ledgers: [String: SyncLedger] = [:]) {
        self.ledgers = ledgers
    }

    public func load(for did: String) throws -> SyncLedger {
        lock.withLock { ledgers[did] ?? SyncLedger() }
    }

    public func save(_ ledger: SyncLedger, for did: String) throws {
        lock.withLock { ledgers[did] = ledger }
    }

    public func clear(for did: String) throws {
        lock.withLock { ledgers[did] = nil }
    }
}
