import Foundation

/// The outcome of a sync or an import.
public struct SyncReport: Equatable, Sendable {
    /// Activities written to the PDS this time.
    public var uploaded: [UUID] = []
    /// Activities that could not be written and will not be retried
    /// automatically, with a message a person can read.
    public var failed: [UUID: String] = [:]

    public init(uploaded: [UUID] = [], failed: [UUID: String] = [:]) {
        self.uploaded = uploaded
        self.failed = failed
    }
}

/// Moves workouts from Apple Health to the PDS for one account.
///
/// Calls are serialised: a background wake-up that arrives while the app is
/// already syncing waits for that sync instead of racing it. Progress is
/// saved to the ledger after every record, so a sync cut short by iOS picks
/// up where it left off.
public actor SyncEngine {
    private let did: String
    private let source: WorkoutSource
    private let writer: RecordWriter
    private let mapper: ActivityRecordMapper
    private let ledgerStore: SyncLedgerStore
    private let now: @Sendable () -> Date

    private var running: Task<Void, Never>?

    public init(
        did: String,
        source: WorkoutSource,
        writer: RecordWriter,
        mapper: ActivityRecordMapper,
        ledgerStore: SyncLedgerStore,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.did = did
        self.source = source
        self.writer = writer
        self.mapper = mapper
        self.ledgerStore = ledgerStore
        self.now = now
    }

    public func ledger() throws -> SyncLedger {
        try ledgerStore.load(for: did)
    }

    /// Uploads every activity that ended since setup, matches `filter`, the
    /// lexicon can represent, and has been neither synced nor removed. Does
    /// nothing before setup has finished.
    public func syncNewActivities(filter: ActivityFilter) async throws -> SyncReport {
        try await exclusively {
            let ledger = try self.ledgerStore.load(for: self.did)
            guard let from = ledger.autoSyncFrom else { return SyncReport() }
            let candidates = try await self.source.workouts(endingAfter: from).filter {
                !ledger.contains($0.id) && !ledger.removed.contains($0.id)
                    && filter.includes($0.activityType) && self.mapper.supports($0.activityType)
            }
            return try await self.upload(candidates)
        }
    }

    /// Uploads exactly `workouts`, whatever the filter says: these are the
    /// ones the person ticked on the import screen. With `finishingSetup`,
    /// automatic syncing then starts from that moment. `progress` is told
    /// how many of how many have been dealt with after each one.
    public func importActivities(
        _ workouts: [Workout],
        finishingSetup: Bool,
        progress: (@Sendable (Int, Int) -> Void)? = nil
    ) async throws -> SyncReport {
        try await exclusively {
            if finishingSetup {
                var ledger = try self.ledgerStore.load(for: self.did)
                if ledger.autoSyncFrom == nil {
                    ledger.autoSyncFrom = self.now()
                    try self.ledgerStore.save(ledger, for: self.did)
                }
            }
            let ledger = try self.ledgerStore.load(for: self.did)
            let pending = workouts.filter { !ledger.contains($0.id) && self.mapper.supports($0.activityType) }
            return try await self.upload(pending, progress: progress)
        }
    }

    /// Deletes the records for `workoutIDs` from the PDS, and makes sure
    /// automatic syncing doesn't put them back. Returns the ones that
    /// couldn't be deleted, with the reason.
    public func remove(_ workoutIDs: [UUID]) async throws -> [UUID: String] {
        try await exclusively {
            var ledger = try self.ledgerStore.load(for: self.did)
            var failed: [UUID: String] = [:]
            for id in workoutIDs {
                guard let entry = ledger.synced[id] else { continue }
                do {
                    try await self.writer.remove(collection: entry.collection, rkey: entry.rkey)
                    ledger.synced[id] = nil
                    ledger.removed.insert(id)
                    try self.ledgerStore.save(ledger, for: self.did)
                } catch let error where !Self.isPerActivity(error) {
                    throw error
                } catch {
                    failed[id] = error.localizedDescription
                }
            }
            return failed
        }
    }

    // MARK: - Internals

    private func upload(_ workouts: [Workout], progress: (@Sendable (Int, Int) -> Void)? = nil) async throws -> SyncReport {
        var report = SyncReport()
        progress?(0, workouts.count)
        // Oldest first, so an interrupted sync leaves a contiguous history.
        for workout in workouts.sorted(by: { $0.start < $1.start }) {
            try Task.checkCancellation()
            let rkey = mapper.recordKey(for: workout)
            do {
                let record = try await mapper.record(for: workout)
                let ref = try await writer.write(collection: mapper.collection, rkey: rkey, record: record)
                var ledger = try ledgerStore.load(for: did)
                ledger.removed.remove(workout.id)
                ledger.synced[workout.id] = SyncedActivity(
                    workoutID: workout.id,
                    activityType: workout.activityType,
                    start: workout.start,
                    collection: mapper.collection,
                    rkey: rkey,
                    uri: ref.uri,
                    syncedAt: now()
                )
                try ledgerStore.save(ledger, for: did)
                report.uploaded.append(workout.id)
            } catch let error where !Self.isPerActivity(error) {
                // Offline, signed out, rate-limited, the PDS is down: nothing
                // else will succeed either, so stop and try again next time.
                throw error
            } catch {
                report.failed[workout.id] = error.localizedDescription
            }
            progress?(report.uploaded.count + report.failed.count, workouts.count)
        }
        return report
    }

    /// A failure that belongs to this one activity (the PDS rejected this
    /// record, or it couldn't be built) rather than to the connection or the
    /// session, which would fail every other activity too.
    static func isPerActivity(_ error: Error) -> Bool {
        if error is ActivityMappingError { return true }
        if let xrpc = error as? XRPCError, case let .server(status, _, _) = xrpc {
            return (400 ..< 500).contains(status) && status != 401 && status != 429
        }
        return false
    }

    /// Runs `work` once any earlier call has finished. Cancelling the caller
    /// (a background task running out of time) cancels `work`.
    private func exclusively<T: Sendable>(_ work: @escaping @Sendable () async throws -> T) async throws -> T {
        while let previous = running {
            await previous.value
            if running == previous { running = nil }
        }
        let task = Task { try await work() }
        let marker = Task { _ = try? await task.value }
        running = marker
        defer { if running == marker { running = nil } }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }
}

/// A workout that can't be turned into a record.
public enum ActivityMappingError: LocalizedError, Equatable, Sendable {
    case unsupportedActivity(ActivityType)
    case missingData(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedActivity:
            return "Kimbia doesn't have a place for this kind of activity yet."
        case let .missingData(what):
            return "Apple Health doesn't have the \(what) Kimbia needs for this activity."
        }
    }
}
