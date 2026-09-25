import Foundation

/// A kind of activity, as HealthKit numbers them: the raw value of
/// `HKWorkoutActivityType` (37 is running, 52 walking, and so on).
///
/// KimbiaKit keeps the raw number rather than HealthKit's enum so it builds
/// and tests anywhere; the app gives each type its name and symbol.
public struct ActivityType: RawRepresentable, Codable, Hashable, Comparable, Sendable {
    public let rawValue: UInt

    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    public static func < (lhs: ActivityType, rhs: ActivityType) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// One workout from Apple Health, reduced to what syncing needs. Quantities
/// are in SI units (metres, seconds, kilocalories, beats per minute) and
/// `nil` when Health has no value.
public struct Workout: Identifiable, Codable, Hashable, Sendable {
    /// HealthKit's UUID for the workout. Stable for the life of the sample.
    public let id: UUID
    public let activityType: ActivityType
    public let start: Date
    public let end: Date
    /// Time spent moving, which excludes pauses and so can be shorter than
    /// `end - start`.
    public let duration: TimeInterval
    public let distance: Double?
    public let activeEnergy: Double?
    public let averageHeartRate: Double?
    public let maximumHeartRate: Double?
    public let elevationAscended: Double?
    /// `true` for a treadmill run or an indoor ride, when Health says so.
    public let isIndoor: Bool?
    /// The app or device that recorded the workout, e.g. "Apple Watch".
    public let sourceName: String?

    public init(
        id: UUID,
        activityType: ActivityType,
        start: Date,
        end: Date,
        duration: TimeInterval,
        distance: Double? = nil,
        activeEnergy: Double? = nil,
        averageHeartRate: Double? = nil,
        maximumHeartRate: Double? = nil,
        elevationAscended: Double? = nil,
        isIndoor: Bool? = nil,
        sourceName: String? = nil
    ) {
        self.id = id
        self.activityType = activityType
        self.start = start
        self.end = end
        self.duration = duration
        self.distance = distance
        self.activeEnergy = activeEnergy
        self.averageHeartRate = averageHeartRate
        self.maximumHeartRate = maximumHeartRate
        self.elevationAscended = elevationAscended
        self.isIndoor = isIndoor
        self.sourceName = sourceName
    }
}

/// Where workouts come from. The app's implementation reads Apple Health.
public protocol WorkoutSource: Sendable {
    /// Workouts that ended after `date` (all of them when `nil`), newest first.
    func workouts(endingAfter date: Date?) async throws -> [Workout]
}
