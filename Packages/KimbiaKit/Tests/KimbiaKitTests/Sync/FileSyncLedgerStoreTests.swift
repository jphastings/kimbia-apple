import XCTest
@testable import KimbiaKit

final class FileSyncLedgerStoreTests: XCTestCase {
    private var directory: URL!
    private var store: FileSyncLedgerStore!

    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        store = FileSyncLedgerStore(directory: directory)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        super.tearDown()
    }

    func test_anAccountWithNoLedgerStartsEmptyAndNotSetUp() throws {
        let ledger = try store.load(for: "did:plc:new")

        XCTAssertEqual(ledger, SyncLedger())
        XCTAssertFalse(ledger.isSetUp)
    }

    func test_aSavedLedgerLoadsBackForTheSameAccountOnly() throws {
        let id = UUID()
        let ledger = SyncLedger(
            autoSyncFrom: Date(timeIntervalSince1970: 1_750_000_000),
            synced: [id: SyncedActivity(
                workoutID: id,
                activityType: ActivityType(rawValue: 37),
                start: Date(timeIntervalSince1970: 1_749_000_000),
                collection: "app.example.activity",
                rkey: "3kabc",
                uri: "at://did:plc:me/app.example.activity/3kabc",
                syncedAt: Date(timeIntervalSince1970: 1_750_000_100)
            )]
        )

        try store.save(ledger, for: "did:plc:me")

        XCTAssertEqual(try store.load(for: "did:plc:me"), ledger)
        XCTAssertEqual(try store.load(for: "did:plc:someone-else"), SyncLedger())
    }

    func test_clearingForgetsTheLedger() throws {
        try store.save(SyncLedger(autoSyncFrom: Date(timeIntervalSince1970: 0)), for: "did:plc:me")

        try store.clear(for: "did:plc:me")

        XCTAssertEqual(try store.load(for: "did:plc:me"), SyncLedger())
    }
}
