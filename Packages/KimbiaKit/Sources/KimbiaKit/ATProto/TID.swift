import Foundation

/// Generates ATProto Timestamp Identifiers: the client-chosen record keys
/// that make a write idempotent. See https://atproto.com/specs/tid.
///
/// A TID is a 64-bit integer — top bit `0`, then 53 bits of microseconds
/// since the Unix epoch, then 10 bits of random "clock identifier" — encoded
/// as 13 characters of base32-sortable text, so TIDs minted in order also
/// sort in order.
public enum TID {
    private static let alphabet = Array("234567abcdefghijklmnopqrstuvwxyz")
    private static let clock = MonotonicMicroseconds()

    /// A new TID, unique and strictly greater than every other one minted by
    /// this process, even when called repeatedly within the same microsecond.
    public static func next(now: Date = Date()) -> String {
        let requested = UInt64(max(now.timeIntervalSince1970, 0) * 1_000_000)
        let micros = clock.next(atLeast: requested)
        let clockID = UInt64.random(in: 0 ..< 1024)
        // 53 bits of micros, then 10 bits of clock id; the remaining top bit
        // of the 64-bit value is left 0, as the spec requires.
        let value = ((micros & 0x1F_FFFF_FFFF_FFFF) << 10) | clockID
        return encode(value)
    }

    /// A TID fixed by `date` and `discriminator` rather than by the clock:
    /// the same inputs always give the same TID. Used as the record key for
    /// an activity (its start time, and its HealthKit UUID as the clock
    /// identifier), so re-syncing an activity after a reinstall overwrites
    /// its record instead of adding a duplicate, while keys still sort by
    /// when the activity happened.
    public static func stable(date: Date, discriminator: UUID) -> String {
        let micros = UInt64(max(date.timeIntervalSince1970, 0) * 1_000_000)
        let bytes = discriminator.uuid
        let clockID = (UInt64(bytes.0) << 2 | UInt64(bytes.1) >> 6) & 0x3FF
        let value = ((micros & 0x1F_FFFF_FFFF_FFFF) << 10) | clockID
        return encode(value)
    }

    private static func encode(_ value: UInt64) -> String {
        var characters = [Character](repeating: alphabet[0], count: 13)
        var remaining = value
        for index in stride(from: 12, through: 0, by: -1) {
            characters[index] = alphabet[Int(remaining & 0x1F)]
            remaining >>= 5
        }
        return String(characters)
    }
}

/// Hands out ever-increasing microsecond values, process-wide, so TIDs minted
/// in a tight loop (easily within the same microsecond) never collide.
private final class MonotonicMicroseconds: @unchecked Sendable {
    private let lock = NSLock()
    private var last: UInt64 = 0

    func next(atLeast requested: UInt64) -> UInt64 {
        lock.withLock {
            last = Swift.max(requested, last + 1)
            return last
        }
    }
}
