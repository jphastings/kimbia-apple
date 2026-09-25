import Foundation

/// Writes workouts as `app.kimbia.activity` records.
///
/// Follows the lexicon Kimbia publishes at
/// `at://kimbia.app/com.atproto.lexicon.schema/app.kimbia.activity`:
/// decimals are strings (DAG-CBOR has no floats), durations whole seconds,
/// and the privacy rules for `startedAt`, `elapsedTime`, `polyline` and
/// `altitude` are those the lexicon describes.
public struct KimbiaActivityMapper: ActivityRecordMapper {
    public static let collection = "app.kimbia.activity"
    /// Upper bound the lexicon puts on `polyline` and `altitude`.
    static let maxStreamLength = 20000

    private let privacy: @Sendable () -> KimbiaPrivacy
    private let routes: RouteSource?

    /// - Parameters:
    ///   - privacy: Read afresh for every record, so a change applies to
    ///     the next sync.
    ///   - routes: Where to find a workout's route; `nil` never adds a map.
    public init(privacy: @escaping @Sendable () -> KimbiaPrivacy = { KimbiaPrivacy() }, routes: RouteSource? = nil) {
        self.privacy = privacy
        self.routes = routes
    }

    public var collection: String { Self.collection }

    /// Every type has a place: the ones Kimbia doesn't name become "other".
    public func supports(_ type: ActivityType) -> Bool {
        true
    }

    public func record(for workout: Workout) async throws -> JSONValue {
        let privacy = privacy()
        var fields: [String: JSONValue] = [
            "$type": .string(Self.collection),
            "sportType": .string(Self.sportType(for: workout.activityType)),
            "startedAt": .string(Self.startedAt(workout, exact: privacy.shareExactTimes)),
            "distance": .string(Self.decimal(workout.distance ?? 0, places: 1)),
            "movingTime": .integer(Int(workout.duration.rounded())),
            "source": "apple-health",
        ]
        if privacy.shareExactTimes {
            fields["elapsedTime"] = .integer(Int(workout.end.timeIntervalSince(workout.start).rounded()))
        }
        if let distance = workout.distance, distance > 0, workout.duration > 0 {
            fields["avgSpeed"] = .string(Self.decimal(distance / workout.duration, places: 3))
        }
        if let gain = workout.elevationAscended {
            fields["elevationGain"] = .string(Self.decimal(gain, places: 1))
        }
        if let device = workout.deviceName ?? workout.sourceName, !device.isEmpty {
            fields["device"] = .string(String(device.prefix(300)))
        }
        if privacy.route != .hidden, let routes, let points = try await routes.route(for: workout) {
            for (key, value) in Self.mapFields(points, route: privacy.route) {
                fields[key] = .string(value)
            }
        }
        return .object(fields)
    }

    // MARK: - Fields

    /// Kimbia's `sportType` for a HealthKit activity type.
    static func sportType(for type: ActivityType) -> String {
        switch type.rawValue {
        case 37, 49, 71: return "run" // running, track and field, wheelchair run pace
        case 13, 74: return "ride" // cycling, hand cycling
        case 46: return "swim"
        case 52, 70: return "walk" // walking, wheelchair walk pace
        case 24: return "hike"
        default: return "other"
        }
    }

    /// By default the day the activity started, where it happened, as noon
    /// UTC; with exact times, the true start with its local offset.
    static func startedAt(_ workout: Workout, exact: Bool) -> String {
        let zone = workout.timeZoneIdentifier.flatMap(TimeZone.init(identifier:)) ?? .current
        if exact {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            formatter.timeZone = zone
            return formatter.string(from: workout.start)
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let day = calendar.dateComponents([.year, .month, .day], from: workout.start)
        return String(format: "%04d-%02d-%02dT12:00:00.000Z", day.year!, day.month!, day.day!)
    }

    /// `polyline`, and `altitude` when every kept point has one. Nothing when
    /// cropping leaves no route.
    static func mapFields(_ points: [RoutePoint], route: KimbiaPrivacy.Route) -> [String: String] {
        let visible = route == .cropped ? Polyline.cropped(points, radius: KimbiaPrivacy.cropRadius) : points
        guard visible.count >= 2 else { return [:] }
        let hasAltitude = visible.allSatisfy { $0.altitude != nil }
        let kept = Polyline.simplified(visible, toFit: maxStreamLength, includingAltitude: hasAltitude)
        var fields = ["polyline": Polyline.encode(kept)]
        if hasAltitude {
            fields["altitude"] = Polyline.encodeDeltas(kept.map { Int($0.altitude!.rounded()) })
        }
        return fields
    }

    /// A decimal as the lexicon wants it: plain digits, a full stop, at most
    /// `places` decimals and no trailing zeros ("51214.6", "5000").
    static func decimal(_ value: Double, places: Int) -> String {
        var text = String(format: "%.\(places)f", value)
        if text.contains(".") {
            while text.hasSuffix("0") { text.removeLast() }
            if text.hasSuffix(".") { text.removeLast() }
        }
        return text == "-0" ? "0" : text
    }
}
