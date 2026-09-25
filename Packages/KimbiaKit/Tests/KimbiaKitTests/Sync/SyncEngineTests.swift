import XCTest
@testable import KimbiaKit

final class SyncEngineTests: XCTestCase {
    private let did = "did:plc:me"
    private var source: FakeWorkoutSource!
    private var writer: FakeRecordWriter!
    private var ledgers: InMemorySyncLedgerStore!
    private var filter: ActivityFilter!

    override func setUp() {
        super.setUp()
        source = FakeWorkoutSource()
        writer = FakeRecordWriter()
        ledgers = InMemorySyncLedgerStore()
        filter = ActivityFilter()
        filter.set(.running, included: true)
        filter.set(.walking, included: false)
    }

    private func engine(now: Date = Clock.setUp) -> SyncEngine {
        SyncEngine(did: did, source: source, writer: writer, mapper: FakeMapper(), ledgerStore: ledgers, now: { now })
    }

    private func finishSetUp() async throws {
        _ = try await engine().importActivities([], finishingSetup: true)
    }

    // MARK: - Automatic sync

    func test_nothingIsSyncedAutomaticallyBeforeSetUpIsFinished() async throws {
        source.workouts = [workout(.running, endingMinutesAfterSetUp: 10)]

        let report = try await engine().syncNewActivities(filter: filter)

        XCTAssertEqual(report, SyncReport())
        XCTAssertEqual(writer.writes, 0)
    }

    func test_afterSetUpNewActivitiesMatchingTheFilterAreSynced() async throws {
        try await finishSetUp()
        let run = workout(.running, endingMinutesAfterSetUp: 10)
        let walk = workout(.walking, endingMinutesAfterSetUp: 20)
        source.workouts = [run, walk]

        let report = try await engine().syncNewActivities(filter: filter)

        XCTAssertEqual(report.uploaded, [run.id])
        XCTAssertTrue(try ledgers.load(for: did).contains(run.id))
        XCTAssertFalse(try ledgers.load(for: did).contains(walk.id))
    }

    func test_activitiesFromBeforeSetUpAreLeftToTheImportScreen() async throws {
        try await finishSetUp()
        source.workouts = [workout(.running, endingMinutesAfterSetUp: -10)]

        let report = try await engine().syncNewActivities(filter: filter)

        XCTAssertTrue(report.uploaded.isEmpty)
    }

    func test_typesThatFollowOthersAreSyncedOnlyWhenOthersIsOn() async throws {
        try await finishSetUp()
        let ride = workout(.cycling, endingMinutesAfterSetUp: 10)
        source.workouts = [ride]

        let off = try await engine().syncNewActivities(filter: filter)
        filter.includeOthers = true
        let on = try await engine().syncNewActivities(filter: filter)

        XCTAssertTrue(off.uploaded.isEmpty)
        XCTAssertEqual(on.uploaded, [ride.id])
    }

    func test_typesTheLexiconCantRepresentAreSkippedQuietly() async throws {
        try await finishSetUp()
        filter.includeOthers = true
        source.workouts = [workout(.yoga, endingMinutesAfterSetUp: 10)]

        let report = try await engine().syncNewActivities(filter: filter)

        XCTAssertEqual(report, SyncReport())
    }

    func test_anActivityIsOnlyEverUploadedOnce() async throws {
        try await finishSetUp()
        source.workouts = [workout(.running, endingMinutesAfterSetUp: 10)]

        _ = try await engine().syncNewActivities(filter: filter)
        let second = try await engine().syncNewActivities(filter: filter)

        XCTAssertTrue(second.uploaded.isEmpty)
        XCTAssertEqual(writer.writes, 1)
    }

    func test_theRecordKeyIsStableSoALostLedgerOverwritesRatherThanDuplicates() async throws {
        try await finishSetUp()
        let run = workout(.running, endingMinutesAfterSetUp: 10)
        source.workouts = [run]
        _ = try await engine().syncNewActivities(filter: filter)

        var ledger = try ledgers.load(for: did)
        ledger.synced = [:]
        try ledgers.save(ledger, for: did)
        _ = try await engine().syncNewActivities(filter: filter)

        XCTAssertEqual(writer.writes, 2)
        XCTAssertEqual(writer.records.count, 1)
    }

    func test_aRecordThePDSRejectsIsReportedAndTheRestStillSync() async throws {
        try await finishSetUp()
        let bad = workout(.running, endingMinutesAfterSetUp: 10)
        let good = workout(.running, endingMinutesAfterSetUp: 20)
        source.workouts = [bad, good]
        writer.failures[FakeMapper().recordKey(for: bad)] = XRPCError.server(status: 400, error: "InvalidRecord", message: "Record is invalid")

        let report = try await engine().syncNewActivities(filter: filter)

        XCTAssertEqual(report.uploaded, [good.id])
        XCTAssertEqual(report.failed, [bad.id: "Record is invalid"])
    }

    func test_aConnectionProblemStopsTheSyncSoItCanBeRetriedLater() async throws {
        try await finishSetUp()
        source.workouts = [workout(.running, endingMinutesAfterSetUp: 10), workout(.running, endingMinutesAfterSetUp: 20)]
        writer.failAll = URLError(.notConnectedToInternet)

        do {
            _ = try await engine().syncNewActivities(filter: filter)
            XCTFail("expected the sync to stop")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .notConnectedToInternet)
        }
        XCTAssertEqual(writer.writes, 1, "the second activity should not have been tried")
        XCTAssertTrue(try ledgers.load(for: did).synced.isEmpty)
    }

    func test_anExpiredSessionStopsTheSync() async throws {
        try await finishSetUp()
        source.workouts = [workout(.running, endingMinutesAfterSetUp: 10)]
        writer.failAll = OAuthError.sessionExpired

        do {
            _ = try await engine().syncNewActivities(filter: filter)
            XCTFail("expected the sync to stop")
        } catch {
            XCTAssertEqual(error as? OAuthError, .sessionExpired)
        }
    }

    func test_overlappingSyncsDoNotUploadTheSameActivityTwice() async throws {
        try await finishSetUp()
        source.workouts = [workout(.running, endingMinutesAfterSetUp: 10)]
        writer.delay = .milliseconds(50)
        let engine = engine()
        let filter = filter!

        async let first = engine.syncNewActivities(filter: filter)
        async let second = engine.syncNewActivities(filter: filter)
        let reports = try await [first, second]

        XCTAssertEqual(reports.map(\.uploaded.count).reduce(0, +), 1)
        XCTAssertEqual(writer.writes, 1)
    }

    // MARK: - Import

    func test_importUploadsExactlyTheTickedActivitiesWhateverTheFilter() async throws {
        let walk = workout(.walking, endingMinutesAfterSetUp: -100)
        let run = workout(.running, endingMinutesAfterSetUp: -50)

        let report = try await engine().importActivities([walk], finishingSetup: true)

        XCTAssertEqual(report.uploaded, [walk.id])
        XCTAssertFalse(try ledgers.load(for: did).contains(run.id))
    }

    func test_finishingSetUpStartsAutomaticSyncFromThatMoment() async throws {
        _ = try await engine(now: Clock.setUp).importActivities([], finishingSetup: true)

        XCTAssertEqual(try ledgers.load(for: did).autoSyncFrom, Clock.setUp)
    }

    func test_importingAgainLaterDoesNotMoveTheAutomaticSyncStart() async throws {
        _ = try await engine(now: Clock.setUp).importActivities([], finishingSetup: true)
        _ = try await engine(now: Clock.setUp.addingTimeInterval(86400)).importActivities([], finishingSetup: true)

        XCTAssertEqual(try ledgers.load(for: did).autoSyncFrom, Clock.setUp)
    }

    // MARK: - Removal

    func test_removingAnActivityDeletesItsRecordAndForgetsIt() async throws {
        let run = workout(.running, endingMinutesAfterSetUp: -10)
        _ = try await engine().importActivities([run], finishingSetup: true)

        let failed = try await engine().remove([run.id])

        XCTAssertTrue(failed.isEmpty)
        XCTAssertTrue(writer.records.isEmpty)
        XCTAssertFalse(try ledgers.load(for: did).contains(run.id))
    }

    func test_aRemovedActivityIsNotSyncedAgainAutomatically() async throws {
        try await finishSetUp()
        let run = workout(.running, endingMinutesAfterSetUp: 10)
        source.workouts = [run]
        _ = try await engine().syncNewActivities(filter: filter)

        _ = try await engine().remove([run.id])
        let report = try await engine().syncNewActivities(filter: filter)

        XCTAssertTrue(report.uploaded.isEmpty)
        XCTAssertTrue(writer.records.isEmpty)
    }

    func test_aRemovedActivityCanBeImportedAgainByHand() async throws {
        let run = workout(.running, endingMinutesAfterSetUp: -10)
        _ = try await engine().importActivities([run], finishingSetup: true)
        _ = try await engine().remove([run.id])

        let report = try await engine().importActivities([run], finishingSetup: false)

        XCTAssertEqual(report.uploaded, [run.id])
        XCTAssertFalse(try ledgers.load(for: did).removed.contains(run.id))
    }

    func test_aRemovalThePDSRefusesIsReportedAndRemembered() async throws {
        let run = workout(.running, endingMinutesAfterSetUp: -10)
        _ = try await engine().importActivities([run], finishingSetup: true)
        writer.failures[FakeMapper().recordKey(for: run)] = XRPCError.server(status: 403, error: nil, message: "Nope")

        let failed = try await engine().remove([run.id])

        XCTAssertEqual(failed, [run.id: "Nope"])
        XCTAssertTrue(try ledgers.load(for: did).contains(run.id))
    }
}

extension SyncEngineTests {
    func test_importReportsProgressAfterEachActivity() async throws {
        let workouts = (1 ... 3).map { workout(.running, endingMinutesAfterSetUp: Double(-$0 * 60)) }
        let seen = ProgressLog()

        _ = try await engine().importActivities(workouts, finishingSetup: true) { done, total in
            seen.append("\(done)/\(total)")
        }

        XCTAssertEqual(seen.entries, ["0/3", "1/3", "2/3", "3/3"])
    }
}

final class ProgressLog: @unchecked Sendable {
    private let lock = NSLock()
    private var _entries: [String] = []
    var entries: [String] { lock.withLock { _entries } }
    func append(_ entry: String) { lock.withLock { _entries.append(entry) } }
}
