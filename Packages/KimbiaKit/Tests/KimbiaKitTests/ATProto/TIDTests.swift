import Foundation
import XCTest
@testable import KimbiaKit

final class TIDTests: XCTestCase {
    private static let alphabet = Set("234567abcdefghijklmnopqrstuvwxyz")

    func testATIDIs13CharactersFromTheSortableAlphabet() {
        let tid = TID.next()

        XCTAssertEqual(tid.count, 13)
        XCTAssertTrue(tid.allSatisfy { Self.alphabet.contains($0) }, tid)
    }

    func testTIDsMintedInIncreasingOrderSortLexicographically() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let tids = (0 ..< 5).map { offset in
            TID.next(now: base.addingTimeInterval(TimeInterval(offset)))
        }

        XCTAssertEqual(tids, tids.sorted(), "TIDs minted later must sort after TIDs minted earlier")
    }

    func testRepeatedCallsAreAlwaysUnique() {
        // Called in a tight loop they can easily land in the same microsecond.
        let tids = (0 ..< 500).map { _ in TID.next() }

        XCTAssertEqual(Set(tids).count, tids.count)
    }

    func testRepeatedCallsAreStrictlyIncreasingEvenForTheSameRequestedTime() {
        let same = Date(timeIntervalSince1970: 1_700_000_000)
        let first = TID.next(now: same)
        let second = TID.next(now: same)

        XCTAssertLessThan(first, second)
    }

    func testAnOlderRequestedTimeStillSortsAfterAnAlreadyMintedTID() {
        // The process-wide clock only moves forward, so a call with a
        // notionally earlier timestamp (a stale clock, a paused process)
        // still gets a TID that sorts after whatever was minted last.
        let earlier = TID.next(now: Date(timeIntervalSince1970: 1_700_000_100))
        let later = TID.next(now: Date(timeIntervalSince1970: 1_700_000_000))

        XCTAssertLessThan(earlier, later)
    }

    // MARK: - Stable TIDs

    func testAStableTIDIsTheSameEveryTimeForTheSameActivity() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let id = UUID()

        XCTAssertEqual(TID.stable(date: start, discriminator: id), TID.stable(date: start, discriminator: id))
    }

    func testAStableTIDIsAValidTID() {
        let tid = TID.stable(date: Date(timeIntervalSince1970: 1_700_000_000), discriminator: UUID())

        XCTAssertEqual(tid.count, 13)
        XCTAssertTrue(tid.allSatisfy { Self.alphabet.contains($0) }, tid)
        XCTAssertTrue("234567abcdefghij".contains(tid.first!), "the top bit of a TID must be 0")
    }

    func testStableTIDsSortByTheActivitysStartTime() {
        let earlier = TID.stable(date: Date(timeIntervalSince1970: 1_700_000_000), discriminator: UUID())
        let later = TID.stable(date: Date(timeIntervalSince1970: 1_700_000_001), discriminator: UUID())

        XCTAssertLessThan(earlier, later)
    }

    func testActivitiesStartingAtTheSameMomentUsuallyGetDifferentStableTIDs() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let a = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        let b = UUID(uuidString: "FFC00000-0000-0000-0000-000000000000")!

        XCTAssertNotEqual(TID.stable(date: start, discriminator: a), TID.stable(date: start, discriminator: b))
    }
}
