import Foundation
@testable import KimbiaKit

extension ActivityType {
    static let running = ActivityType(rawValue: 37)
    static let walking = ActivityType(rawValue: 52)
    static let cycling = ActivityType(rawValue: 13)
    static let yoga = ActivityType(rawValue: 57)
}

enum Clock {
    static let setUp = Date(timeIntervalSince1970: 1_750_000_000)
}

func workout(_ type: ActivityType, endingMinutesAfterSetUp minutes: Double, id: UUID = UUID()) -> Workout {
    let end = Clock.setUp.addingTimeInterval(minutes * 60)
    return Workout(id: id, activityType: type, start: end.addingTimeInterval(-1800), end: end, duration: 1800, distance: 5000)
}

final class FakeWorkoutSource: WorkoutSource, @unchecked Sendable {
    private let lock = NSLock()
    private var _workouts: [Workout]
    private(set) var queries: [Date?] = []
    var error: Error?

    init(_ workouts: [Workout] = []) {
        _workouts = workouts
    }

    var workouts: [Workout] {
        get { lock.withLock { _workouts } }
        set { lock.withLock { _workouts = newValue } }
    }

    func workouts(endingAfter date: Date?) async throws -> [Workout] {
        try lock.withLock {
            queries.append(date)
            if let error { throw error }
            return _workouts.filter { date == nil || $0.end > date! }.sorted { $0.end > $1.end }
        }
    }
}

final class FakeRecordWriter: RecordWriter, @unchecked Sendable {
    private let lock = NSLock()
    private(set) var records: [String: JSONValue] = [:]
    private(set) var writes = 0
    /// Answers for particular rkeys, in place of success.
    var failures: [String: Error] = [:]
    /// Applies to every call when set.
    var failAll: Error?
    /// Delays each write, to let a test overlap two syncs.
    var delay: Duration = .zero

    func write(collection: String, rkey: String, record: JSONValue) async throws -> StrongRef {
        if delay > .zero { try await Task.sleep(for: delay) }
        return try lock.withLock {
            writes += 1
            if let failAll { throw failAll }
            if let error = failures[rkey] { throw error }
            records["\(collection)/\(rkey)"] = record
            return StrongRef(uri: "at://did:plc:me/\(collection)/\(rkey)", cid: "bafy\(rkey)")
        }
    }

    func remove(collection: String, rkey: String) async throws {
        try lock.withLock {
            if let failAll { throw failAll }
            if let error = failures[rkey] { throw error }
            records["\(collection)/\(rkey)"] = nil
        }
    }
}

/// Supports everything but yoga, and records the workout's UUID so tests
/// can see what was written.
struct FakeMapper: ActivityRecordMapper {
    var collection: String { "app.example.activity" }

    func supports(_ type: ActivityType) -> Bool {
        type != .yoga
    }

    func record(for workout: Workout) async throws -> JSONValue {
        ["$type": .string(collection), "workout": .string(workout.id.uuidString)]
    }
}
