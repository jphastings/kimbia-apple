import Foundation

/// How much of an activity is made public. Records in a PDS are public, so
/// these mirror the choices Kimbia offers for the activities it publishes,
/// with the same defaults.
public struct KimbiaPrivacy: Codable, Equatable, Sendable {
    public enum Route: String, Codable, CaseIterable, Sendable {
        /// No map at all.
        case hidden
        /// The route without its first and last stretch, so it doesn't
        /// show where you started or finished.
        case cropped
        /// The whole route.
        case full
    }

    /// When `false` (the default), only the day of the activity is shared,
    /// written as noon UTC, and the elapsed time is left out.
    public var shareExactTimes: Bool
    public var route: Route

    public init(shareExactTimes: Bool = false, route: Route = .cropped) {
        self.shareExactTimes = shareExactTimes
        self.route = route
    }

    /// How far from the start and finish a cropped route is trimmed.
    public static let cropRadius: Double = 500
}
