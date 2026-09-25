import XCTest
@testable import KimbiaKit

final class ActivityFilterTests: XCTestCase {
    func test_typesWithoutAChoiceFollowOthersWhichIsOffByDefault() {
        var filter = ActivityFilter()
        XCTAssertFalse(filter.includes(.running))

        filter.includeOthers = true
        XCTAssertTrue(filter.includes(.running))
    }

    func test_aTypesOwnChoiceWinsOverOthers() {
        var filter = ActivityFilter(includeOthers: true)
        filter.set(.walking, included: false)
        filter.set(.running, included: true)

        XCTAssertFalse(filter.includes(.walking))
        XCTAssertTrue(filter.includes(.running))
        XCTAssertTrue(filter.includes(.cycling), "cycling has no choice of its own, so follows others")
    }

    func test_removingAChoiceHandsTheTypeBackToOthers() {
        var filter = ActivityFilter(includeOthers: true)
        filter.set(.walking, included: false)
        filter.removeChoice(for: .walking)

        XCTAssertFalse(filter.hasChoice(for: .walking))
        XCTAssertTrue(filter.includes(.walking))
    }

    func test_adoptingTypesGivesNewOnesAChoiceButLeavesExistingChoicesAlone() {
        var filter = ActivityFilter()
        filter.set(.walking, included: false)

        filter.adopt([.running, .walking], included: true)

        XCTAssertTrue(filter.includes(.running))
        XCTAssertFalse(filter.includes(.walking))
    }

    func test_newlyExcludedNamesOnlyTypesThatWereSyncedAndNowAreNot() {
        var before = ActivityFilter()
        before.set(.running, included: true)
        before.set(.walking, included: true)
        var after = before
        after.set(.walking, included: false)
        after.set(.cycling, included: false)

        XCTAssertEqual(after.newlyExcluded(since: before, among: [.running, .walking, .cycling]), [.walking])
    }

    func test_turningOthersOffExcludesTypesThatFollowedIt() {
        let before = ActivityFilter(includeOthers: true)
        let after = ActivityFilter(includeOthers: false)

        XCTAssertEqual(after.newlyExcluded(since: before, among: [.yoga]), [.yoga])
    }

    func test_survivesARoundTripThroughJSON() throws {
        var filter = ActivityFilter(includeOthers: true)
        filter.set(.walking, included: false)

        let decoded = try JSONDecoder().decode(ActivityFilter.self, from: JSONEncoder().encode(filter))

        XCTAssertEqual(decoded, filter)
    }
}
