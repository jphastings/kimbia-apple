import XCTest
@testable import KimbiaKit

final class KimbiaActivityMapperTests: XCTestCase {
    /// 09:30 in London (BST, +01:00) on 30 June 2026.
    private let start = ISO8601DateFormatter().date(from: "2026-06-30T08:30:00Z")!

    private func run(
        distance: Double? = 10_000,
        duration: TimeInterval = 3000,
        elapsed: TimeInterval = 3100,
        timeZone: String? = "Europe/London"
    ) -> Workout {
        Workout(
            id: UUID(),
            activityType: .running,
            start: start,
            end: start.addingTimeInterval(elapsed),
            duration: duration,
            distance: distance,
            elevationAscended: 42.37,
            sourceName: "Workout",
            deviceName: "Apple Watch",
            timeZoneIdentifier: timeZone
        )
    }

    private func record(_ workout: Workout, privacy: KimbiaPrivacy = KimbiaPrivacy(), route: [RoutePoint]? = nil) async throws -> JSONValue {
        let mapper = KimbiaActivityMapper(privacy: { privacy }, routes: FixedRoute(points: route))
        return try await mapper.record(for: workout)
    }

    // MARK: - Required fields

    func test_aRecordHasEveryFieldTheLexiconRequires() async throws {
        let record = try await record(run())

        XCTAssertEqual(record["$type"], "app.kimbia.activity")
        XCTAssertEqual(record["sportType"], "run")
        XCTAssertEqual(record["distance"], "10000")
        XCTAssertEqual(record["movingTime"], 3000)
        XCTAssertNotNil(record["startedAt"])
    }

    func test_decimalsAreStringsWithoutTrailingZeros() async throws {
        let record = try await record(run(distance: 51214.63, duration: 3600))

        XCTAssertEqual(record["distance"], "51214.6")
        XCTAssertEqual(record["avgSpeed"], "14.226")
        XCTAssertEqual(record["elevationGain"], "42.4")
    }

    func test_aWorkoutWithNoDistanceStillHasOneOfZero() async throws {
        let record = try await record(run(distance: nil))

        XCTAssertEqual(record["distance"], "0")
        XCTAssertNil(record["avgSpeed"])
    }

    func test_theDeviceAndSourceAreRecorded() async throws {
        let record = try await record(run())

        XCTAssertEqual(record["device"], "Apple Watch")
        XCTAssertEqual(record["source"], "apple-health")
    }

    // MARK: - Sport types

    func test_healthKitTypesMapToKimbiasSportTypes() {
        let cases: [(UInt, String)] = [(37, "run"), (13, "ride"), (46, "swim"), (52, "walk"), (24, "hike"), (57, "other"), (3000, "other")]
        for (raw, expected) in cases {
            XCTAssertEqual(KimbiaActivityMapper.sportType(for: ActivityType(rawValue: raw)), expected, "type \(raw)")
        }
    }

    // MARK: - Times

    func test_byDefaultOnlyTheLocalDayIsSharedAsNoonUTC() async throws {
        let record = try await record(run())

        XCTAssertEqual(record["startedAt"], "2026-06-30T12:00:00.000Z")
        XCTAssertNil(record["elapsedTime"])
    }

    func test_theDayIsTheOneWhereTheWorkoutHappened() async throws {
        // 23:30 UTC on the 30th is already the 1st in Tokyo.
        let late = Workout(id: UUID(), activityType: .running, start: ISO8601DateFormatter().date(from: "2026-06-30T23:30:00Z")!,
                           end: ISO8601DateFormatter().date(from: "2026-07-01T00:00:00Z")!, duration: 1800, timeZoneIdentifier: "Asia/Tokyo")

        let record = try await record(late)

        XCTAssertEqual(record["startedAt"], "2026-07-01T12:00:00.000Z")
    }

    func test_withExactTimesTheTrueStartAndElapsedTimeAreShared() async throws {
        let record = try await record(run(), privacy: KimbiaPrivacy(shareExactTimes: true))

        XCTAssertEqual(record["startedAt"], "2026-06-30T09:30:00.000+01:00")
        XCTAssertEqual(record["elapsedTime"], 3100)
    }

    // MARK: - Routes

    private var route: [RoutePoint] {
        (0 ... 30).map { RoutePoint(latitude: 51.5 + Double($0) * 0.0009, longitude: -0.1, altitude: 10 + Double($0)) }
    }

    func test_aHiddenRouteAddsNoMap() async throws {
        let record = try await record(run(), privacy: KimbiaPrivacy(route: .hidden), route: route)

        XCTAssertNil(record["polyline"])
        XCTAssertNil(record["altitude"])
    }

    func test_aFullRouteStartsWhereTheWorkoutStarted() async throws {
        let record = try await record(run(), privacy: KimbiaPrivacy(route: .full), route: route)

        XCTAssertEqual(record["polyline"]?.stringValue?.hasPrefix(Polyline.encode([route[0]])), true)
        XCTAssertNotNil(record["altitude"])
    }

    func test_aCroppedRouteDoesNotStartWhereTheWorkoutStarted() async throws {
        let record = try await record(run(), privacy: KimbiaPrivacy(route: .cropped), route: route)

        let polyline = try XCTUnwrap(record["polyline"]?.stringValue)
        XCTAssertFalse(polyline.hasPrefix(Polyline.encode([route[0]])))
    }

    func test_altitudeIsLeftOutWhenAnyPointLacksIt() async throws {
        let flat = route.map { RoutePoint(latitude: $0.latitude, longitude: $0.longitude) }

        let record = try await record(run(), privacy: KimbiaPrivacy(route: .full), route: flat)

        XCTAssertNotNil(record["polyline"])
        XCTAssertNil(record["altitude"])
    }

    func test_aRecordSurvivesEncodingAsJSON() async throws {
        let record = try await record(run(), privacy: KimbiaPrivacy(route: .full), route: route)

        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(record)) as? [String: Any]
        XCTAssertEqual(object?["movingTime"] as? Int, 3000)
        XCTAssertEqual(object?["distance"] as? String, "10000")
    }
}

private struct FixedRoute: RouteSource {
    let points: [RoutePoint]?
    func route(for workout: Workout) async throws -> [RoutePoint]? { points }
}
