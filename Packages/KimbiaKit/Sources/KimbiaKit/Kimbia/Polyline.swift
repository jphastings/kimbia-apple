import Foundation

/// Google's encoded polyline format, and the route handling Kimbia's
/// lexicon asks for around it.
/// See https://developers.google.com/maps/documentation/utilities/polylinealgorithm
public enum Polyline {
    /// Encodes points at `precision` decimal places (5 for Kimbia).
    public static func encode(_ points: [RoutePoint], precision: Int = 5) -> String {
        let factor = pow(10, Double(precision))
        var output = ""
        var previous = (lat: 0, lon: 0)
        for point in points {
            let lat = Int((point.latitude * factor).rounded())
            let lon = Int((point.longitude * factor).rounded())
            appendSigned(lat - previous.lat, to: &output)
            appendSigned(lon - previous.lon, to: &output)
            previous = (lat, lon)
        }
        return output
    }

    /// Encodes whole numbers as a stream of differences in the same
    /// signed-varint alphabet: how Kimbia's `altitude` field is written.
    public static func encodeDeltas(_ values: [Int]) -> String {
        var output = ""
        var previous = 0
        for value in values {
            appendSigned(value - previous, to: &output)
            previous = value
        }
        return output
    }

    private static func appendSigned(_ value: Int, to output: inout String) {
        var remaining = value < 0 ? ~(value << 1) : value << 1
        while remaining >= 0x20 {
            output.unicodeScalars.append(Unicode.Scalar(UInt8((0x20 | (remaining & 0x1F)) + 63)))
            remaining >>= 5
        }
        output.unicodeScalars.append(Unicode.Scalar(UInt8(remaining + 63)))
    }

    // MARK: - Privacy trimming

    /// Drops the parts of the route within `radius` metres of where it
    /// starts and where it ends, so a route from your front door doesn't
    /// show where your front door is. Empty when nothing is left.
    public static func cropped(_ points: [RoutePoint], radius: Double) -> [RoutePoint] {
        guard let first = points.first, let last = points.last else { return [] }
        guard let start = points.firstIndex(where: { distance(from: first, to: $0) > radius }),
              let end = points.lastIndex(where: { distance(from: last, to: $0) > radius }),
              start <= end
        else { return [] }
        return Array(points[start ... end])
    }

    // MARK: - Simplification

    /// Removes points until both the encoded route and one altitude per
    /// point fit in `maxLength` characters, keeping the shape as closely as
    /// possible (Ramer–Douglas–Peucker with a growing tolerance).
    public static func simplified(_ points: [RoutePoint], toFit maxLength: Int, includingAltitude: Bool) -> [RoutePoint] {
        var tolerance = 2.0
        var result = points
        while !fits(result, maxLength: maxLength, includingAltitude: includingAltitude) {
            result = douglasPeucker(points, tolerance: tolerance)
            tolerance *= 1.5
        }
        return result
    }

    private static func fits(_ points: [RoutePoint], maxLength: Int, includingAltitude: Bool) -> Bool {
        guard encode(points).count <= maxLength else { return false }
        guard includingAltitude else { return true }
        return encodeDeltas(points.map { Int(($0.altitude ?? 0).rounded()) }).count <= maxLength
    }

    private static func douglasPeucker(_ points: [RoutePoint], tolerance: Double) -> [RoutePoint] {
        guard points.count > 2 else { return points }
        var keep = [Bool](repeating: false, count: points.count)
        keep[0] = true
        keep[points.count - 1] = true
        var stack = [(0, points.count - 1)]
        while let (from, to) = stack.popLast() {
            guard to > from + 1 else { continue }
            var farthest = from
            var farthestDistance = 0.0
            for index in (from + 1) ..< to {
                let d = perpendicularDistance(points[index], from: points[from], to: points[to])
                if d > farthestDistance {
                    farthest = index
                    farthestDistance = d
                }
            }
            if farthestDistance > tolerance {
                keep[farthest] = true
                stack.append((from, farthest))
                stack.append((farthest, to))
            }
        }
        return points.indices.filter { keep[$0] }.map { points[$0] }
    }

    // MARK: - Geometry

    private static let earthRadius = 6_371_000.0

    /// Great-circle distance in metres.
    static func distance(from a: RoutePoint, to b: RoutePoint) -> Double {
        let lat1 = a.latitude * .pi / 180, lat2 = b.latitude * .pi / 180
        let dLat = lat2 - lat1
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * earthRadius * asin(min(1, sqrt(h)))
    }

    /// Distance in metres from `point` to the segment `a`–`b`, on a local
    /// flat projection (plenty accurate at the scale of a workout).
    private static func perpendicularDistance(_ point: RoutePoint, from a: RoutePoint, to b: RoutePoint) -> Double {
        let metresPerDegreeLat = earthRadius * .pi / 180
        let metresPerDegreeLon = metresPerDegreeLat * cos(a.latitude * .pi / 180)
        func project(_ p: RoutePoint) -> (x: Double, y: Double) {
            ((p.longitude - a.longitude) * metresPerDegreeLon, (p.latitude - a.latitude) * metresPerDegreeLat)
        }
        let p = project(point), end = project(b)
        let lengthSquared = end.x * end.x + end.y * end.y
        guard lengthSquared > 0 else { return (p.x * p.x + p.y * p.y).squareRoot() }
        let t = max(0, min(1, (p.x * end.x + p.y * end.y) / lengthSquared))
        let dx = p.x - t * end.x, dy = p.y - t * end.y
        return (dx * dx + dy * dy).squareRoot()
    }
}
