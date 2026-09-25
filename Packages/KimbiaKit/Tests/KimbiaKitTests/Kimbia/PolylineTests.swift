import XCTest
@testable import KimbiaKit

final class PolylineTests: XCTestCase {
    func test_encodesGooglesWorkedExample() {
        let points = [
            RoutePoint(latitude: 38.5, longitude: -120.2),
            RoutePoint(latitude: 40.7, longitude: -120.95),
            RoutePoint(latitude: 43.252, longitude: -126.453),
        ]

        XCTAssertEqual(Polyline.encode(points), "_p~iF~ps|U_ulLnnqC_mqNvxq`@")
    }

    func test_altitudesAreEncodedAsDifferencesInTheSameAlphabet() {
        // 38.5 → 3850000 is "_p~iF" in the example above, so 3850000 then
        // 3850000 + 220000 (40.7) must encode the same way.
        XCTAssertEqual(Polyline.encodeDeltas([3_850_000, 4_070_000]), "_p~iF_ulL")
        XCTAssertEqual(Polyline.encodeDeltas([12, 12, 10]), "W?B")
    }

    func test_croppingDropsTheStartAndFinishButKeepsTheMiddle() {
        // A 2 km straight line north, one point every 100 m.
        let points = (0 ... 20).map { RoutePoint(latitude: 51.5 + Double($0) * 0.0009, longitude: -0.1) }

        let cropped = Polyline.cropped(points, radius: 500)

        XCTAssertFalse(cropped.isEmpty)
        XCTAssertGreaterThan(Polyline.distance(from: points.first!, to: cropped.first!), 500)
        XCTAssertGreaterThan(Polyline.distance(from: points.last!, to: cropped.last!), 500)
    }

    func test_aRouteThatNeverLeavesTheCropRadiusDisappears() {
        let points = (0 ... 10).map { RoutePoint(latitude: 51.5 + Double($0) * 0.0001, longitude: -0.1) }

        XCTAssertTrue(Polyline.cropped(points, radius: 500).isEmpty)
    }

    func test_aLoopThatReturnsHomeLosesBothEnds() {
        // Out 1 km east and back again.
        let out = (0 ... 10).map { RoutePoint(latitude: 51.5, longitude: -0.1 + Double($0) * 0.00144) }
        let loop = out + out.reversed().dropFirst()

        let cropped = Polyline.cropped(loop, radius: 500)

        XCTAssertTrue(cropped.allSatisfy { Polyline.distance(from: loop.first!, to: $0) > 500 })
    }

    func test_simplifyingKeepsLongRoutesWithinTheLimit() {
        // A wiggly 10 000 point route, far too long to encode whole.
        let points = (0 ..< 10000).map { i in
            RoutePoint(latitude: 51.5 + Double(i) * 0.0001, longitude: -0.1 + sin(Double(i) / 5) * 0.001, altitude: 30 + sin(Double(i) / 50) * 20)
        }

        let kept = Polyline.simplified(points, toFit: 20000, includingAltitude: true)

        XCTAssertLessThanOrEqual(Polyline.encode(kept).count, 20000)
        XCTAssertLessThanOrEqual(Polyline.encodeDeltas(kept.map { Int($0.altitude!.rounded()) }).count, 20000)
        XCTAssertEqual(kept.first, points.first)
        XCTAssertEqual(kept.last, points.last)
    }

    func test_shortRoutesAreLeftAlone() {
        let points = (0 ..< 50).map { RoutePoint(latitude: 51.5 + Double($0) * 0.0001, longitude: -0.1 + Double($0 % 3) * 0.0001) }

        XCTAssertEqual(Polyline.simplified(points, toFit: 20000, includingAltitude: false), points)
    }
}
