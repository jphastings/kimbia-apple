import CoreLocation
import HealthKit
import KimbiaKit

/// Reads workouts from Apple Health.
///
/// Health never says whether read access was granted (a refusal simply
/// looks like having no data), so the app only tracks whether it has asked.
final class HealthKitWorkoutSource: WorkoutSource, RouteSource, @unchecked Sendable {
    static let shared = HealthKitWorkoutSource()

    let store = HKHealthStore()

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Everything the app may read. The workout itself plus the quantities
    /// summarised on it, its route, and heart rate during it.
    static let readTypes: Set<HKObjectType> = [
        HKObjectType.workoutType(),
        HKSeriesType.workoutRoute(),
        HKQuantityType(.heartRate),
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.distanceWalkingRunning),
        HKQuantityType(.distanceCycling),
        HKQuantityType(.distanceSwimming),
        HKQuantityType(.distanceWheelchair),
        HKQuantityType(.distanceDownhillSnowSports),
    ]

    /// Whether the permission sheet still needs showing.
    func needsAuthorisation() async -> Bool {
        guard Self.isAvailable else { return false }
        let status = try? await store.statusForAuthorizationRequest(toShare: [], read: Self.readTypes)
        return status != .unnecessary
    }

    func requestAuthorisation() async throws {
        try await store.requestAuthorization(toShare: [], read: Self.readTypes)
    }

    func workouts(endingAfter date: Date?) async throws -> [Workout] {
        // The default options match samples overlapping the window, i.e.
        // ones that end after `date`.
        let predicate = date.map { HKQuery.predicateForSamples(withStart: $0, end: nil) }
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)]
        )
        let results = try await descriptor.result(for: store)
        return results
            .filter { date == nil || $0.endDate > date! }
            .map(Workout.init(healthKit:))
    }

    func route(for workout: Workout) async throws -> [RoutePoint]? {
        let matching = HKSampleQueryDescriptor(
            predicates: [.workout(HKQuery.predicateForObject(with: workout.id))],
            sortDescriptors: []
        )
        guard let healthKitWorkout = try await matching.result(for: store).first else { return nil }

        let routes = HKSampleQueryDescriptor(
            predicates: [.sample(type: HKSeriesType.workoutRoute(), predicate: HKQuery.predicateForObjects(from: healthKitWorkout))],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        var points: [RoutePoint] = []
        for case let route as HKWorkoutRoute in try await routes.result(for: store) {
            for try await location in HKWorkoutRouteQueryDescriptor(route).results(for: store) {
                guard location.horizontalAccuracy >= 0 else { continue }
                points.append(RoutePoint(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    altitude: location.verticalAccuracy >= 0 ? location.altitude : nil
                ))
            }
        }
        return points.isEmpty ? nil : points
    }
}

extension Workout {
    init(healthKit workout: HKWorkout) {
        let bpm = HKUnit.count().unitDivided(by: .minute())
        let heartRate = workout.statistics(for: HKQuantityType(.heartRate))
        // Whichever distance type the activity records (walking/running,
        // cycling, swimming…), found without naming them all so newer
        // types are picked up too.
        let distance = workout.allStatistics
            .first { type, statistics in
                type.identifier.hasPrefix("HKQuantityTypeIdentifierDistance") && statistics.sumQuantity() != nil
            }?
            .value.sumQuantity()?.doubleValue(for: .meter())
        let elevation = (workout.metadata?[HKMetadataKeyElevationAscended] as? HKQuantity)?.doubleValue(for: .meter())

        self.init(
            id: workout.uuid,
            activityType: ActivityType(workout.workoutActivityType),
            start: workout.startDate,
            end: workout.endDate,
            duration: workout.duration,
            distance: distance,
            activeEnergy: workout.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie()),
            averageHeartRate: heartRate?.averageQuantity()?.doubleValue(for: bpm),
            maximumHeartRate: heartRate?.maximumQuantity()?.doubleValue(for: bpm),
            elevationAscended: elevation,
            isIndoor: (workout.metadata?[HKMetadataKeyIndoorWorkout] as? NSNumber)?.boolValue,
            sourceName: workout.sourceRevision.source.name,
            deviceName: workout.device?.name,
            timeZoneIdentifier: workout.metadata?[HKMetadataKeyTimeZone] as? String
        )
    }
}
