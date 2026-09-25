import Foundation

/// Turns a workout into the record written to the PDS. The only place that
/// knows the shape of Kimbia's lexicon.
public protocol ActivityRecordMapper: Sendable {
    /// The NSID of the collection activities are written to.
    var collection: String { get }
    /// Whether the lexicon has a way to represent `type` at all.
    func supports(_ type: ActivityType) -> Bool
    /// The record for `workout`, including its `$type`.
    func record(for workout: Workout) async throws -> JSONValue
}

extension ActivityRecordMapper {
    /// Stable per activity, so a re-sync overwrites rather than duplicates.
    public func recordKey(for workout: Workout) -> String {
        TID.stable(date: workout.start, discriminator: workout.id)
    }
}

/// Writes and deletes records. `PDSClient` is the real one.
public protocol RecordWriter: Sendable {
    func write(collection: String, rkey: String, record: JSONValue) async throws -> StrongRef
    func remove(collection: String, rkey: String) async throws
}

extension PDSClient: RecordWriter {
    public func write(collection: String, rkey: String, record: JSONValue) async throws -> StrongRef {
        try await putRecord(collection: collection, rkey: rkey, record: record)
    }

    public func remove(collection: String, rkey: String) async throws {
        try await deleteRecord(collection: collection, rkey: rkey)
    }
}
