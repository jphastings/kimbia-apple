import Foundation
import KimbiaKit

/// The person's choices and a little sync bookkeeping, kept in
/// `UserDefaults`. Read by background syncs as well as the UI.
final class Preferences: @unchecked Sendable {
    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    private enum Key {
        static let filter = "activityFilter"
        static let privacy = "kimbiaPrivacy"
        static let lastSync = "lastSuccessfulSync"
        static let lastError = "lastSyncError"
    }

    /// Where `clearSessionOnFreshInstall` keeps its flag.
    var defaultsForFreshInstallCheck: UserDefaults { defaults }

    var filter: ActivityFilter {
        get {
            guard let data = defaults.data(forKey: Key.filter),
                  let filter = try? JSONDecoder().decode(ActivityFilter.self, from: data)
            else { return ActivityFilter() }
            return filter
        }
        set {
            defaults.set(try? JSONEncoder().encode(newValue), forKey: Key.filter)
        }
    }

    /// What's made public about each activity. Applies to activities synced
    /// from then on.
    var privacy: KimbiaPrivacy {
        get {
            guard let data = defaults.data(forKey: Key.privacy),
                  let privacy = try? JSONDecoder().decode(KimbiaPrivacy.self, from: data)
            else { return KimbiaPrivacy() }
            return privacy
        }
        set {
            defaults.set(try? JSONEncoder().encode(newValue), forKey: Key.privacy)
        }
    }

    /// When a sync last finished without a connection or session problem.
    var lastSuccessfulSync: Date? {
        get { defaults.object(forKey: Key.lastSync) as? Date }
        set { defaults.set(newValue, forKey: Key.lastSync) }
    }

    /// Why the most recent sync stopped, if it did. Cleared by a good sync.
    var lastSyncError: String? {
        get { defaults.string(forKey: Key.lastError) }
        set { defaults.set(newValue, forKey: Key.lastError) }
    }
}
