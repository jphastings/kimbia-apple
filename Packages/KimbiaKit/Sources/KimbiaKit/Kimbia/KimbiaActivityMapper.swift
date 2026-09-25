import Foundation

/// Kimbia's lexicon: where activities go and what they look like.
///
/// NOT YET WRITTEN. Kimbia's schemas are published as
/// `at://kimbia.app/com.atproto.lexicon.schema/*`, and the record shape here
/// must follow them exactly. Until it does, `supports` answers `false` for
/// everything, so the app can be set up and tested end to end without
/// writing anything to a PDS.
public struct KimbiaActivityMapper: ActivityRecordMapper {
    public init() {}

    /// Placeholder until the lexicon is wired in.
    public var collection: String { "app.kimbia.activity" }

    public func supports(_ type: ActivityType) -> Bool {
        false
    }

    public func record(for workout: Workout) async throws -> JSONValue {
        throw ActivityMappingError.unsupportedActivity(workout.activityType)
    }
}
