import Foundation

/// Which kinds of activity are synced.
///
/// Every type someone has actually done gets an explicit choice. Every
/// other type, including ones they have never tried, follows the single
/// "others" choice, which is off unless they turn it on. A type can also be
/// given an explicit choice in advance, so a new sport can be allowed (or
/// kept out) before its first workout.
public struct ActivityFilter: Codable, Equatable, Sendable {
    /// Types with their own choice. Anything absent follows `includeOthers`.
    public private(set) var choices: [ActivityType: Bool]
    /// Whether types without their own choice are synced.
    public var includeOthers: Bool

    public init(choices: [ActivityType: Bool] = [:], includeOthers: Bool = false) {
        self.choices = choices
        self.includeOthers = includeOthers
    }

    public func includes(_ type: ActivityType) -> Bool {
        choices[type] ?? includeOthers
    }

    /// Whether `type` has its own choice rather than following "others".
    public func hasChoice(for type: ActivityType) -> Bool {
        choices[type] != nil
    }

    public mutating func set(_ type: ActivityType, included: Bool) {
        choices[type] = included
    }

    /// Drops `type`'s own choice, so it follows "others" again.
    public mutating func removeChoice(for type: ActivityType) {
        choices[type] = nil
    }

    /// Gives each of `types` that has no choice yet the choice `included`,
    /// leaving existing choices alone. Used when someone first sees the
    /// types they have done.
    public mutating func adopt(_ types: some Sequence<ActivityType>, included: Bool) {
        for type in types where choices[type] == nil {
            choices[type] = included
        }
    }

    /// The types among `types` that `previous` synced and this filter no
    /// longer does. Their already-synced activities are left in place, which
    /// is worth telling the person about.
    public func newlyExcluded(since previous: ActivityFilter, among types: some Sequence<ActivityType>) -> Set<ActivityType> {
        Set(types.filter { previous.includes($0) && !includes($0) })
    }
}
