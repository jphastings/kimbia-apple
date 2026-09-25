import Foundation
import KimbiaKit
import Observation

/// Everything the signed-in screens show: the person's workouts from
/// Health, what has been synced, their filter, and how syncing is going.
@MainActor
@Observable
final class SyncModel {
    enum Stage: Equatable {
        case loading
        case needsHealthAccess
        case settingUp
        case ready
    }

    private(set) var stage: Stage = .loading
    /// All workouts in Health, newest first.
    private(set) var workouts: [Workout] = []
    private(set) var ledger = SyncLedger()
    private(set) var isSyncing = false
    private(set) var progress: (done: Int, total: Int)?
    private(set) var lastSuccessfulSync: Date?
    private(set) var lastError: String?

    var filter: ActivityFilter {
        didSet { preferences.filter = filter }
    }

    private let source: HealthKitWorkoutSource
    private let preferences: Preferences

    init(source: HealthKitWorkoutSource = .shared, preferences: Preferences = AppEnvironment.preferences) {
        self.source = source
        self.preferences = preferences
        self.filter = preferences.filter
    }

    // MARK: - Derived

    /// How many workouts of each type are in Health.
    var workoutCounts: [ActivityType: Int] {
        workouts.reduce(into: [:]) { counts, workout in counts[workout.activityType, default: 0] += 1 }
    }

    /// Types with at least one workout, most frequent first.
    var typesDone: [ActivityType] {
        let counts = workoutCounts
        return counts.keys.sorted { a, b in
            if counts[a] != counts[b] { return counts[a]! > counts[b]! }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
    }

    /// What the import screen offers: unsynced workouts from before
    /// automatic syncing began (all of them, before setup), and any you
    /// removed from Kimbia.
    var importable: [Workout] {
        workouts.filter { workout in
            !ledger.contains(workout.id)
                && (ledger.removed.contains(workout.id) || ledger.autoSyncFrom.map { workout.end <= $0 } ?? true)
        }
    }

    /// The most recent workouts, for the home screen.
    var recent: [Workout] {
        Array(workouts.prefix(30))
    }

    func isSynced(_ workout: Workout) -> Bool {
        ledger.contains(workout.id)
    }

    /// How many synced activities there are of each type.
    var syncedCounts: [ActivityType: Int] {
        ledger.synced.values.reduce(into: [:]) { counts, entry in counts[entry.activityType, default: 0] += 1 }
    }

    // MARK: - Loading

    /// Works out which screen to show and loads what it needs.
    func load() async {
        if await source.needsAuthorisation() {
            stage = .needsHealthAccess
            return
        }
        await refresh()
        stage = ledger.isSetUp ? .ready : .settingUp
    }

    /// Re-reads Health, the ledger and the last sync's outcome.
    func refresh() async {
        if let engine = await SyncRunner.shared.currentEngine(), let ledger = try? await engine.ledger() {
            self.ledger = ledger
        }
        lastSuccessfulSync = preferences.lastSuccessfulSync
        lastError = preferences.lastSyncError
        do {
            workouts = try await source.workouts(endingAfter: nil)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func requestHealthAccess() async {
        do {
            try await source.requestAuthorisation()
        } catch {
            lastError = error.localizedDescription
        }
        BackgroundSync.observeWorkouts()
        await load()
    }

    /// On first setup, every type you've done starts ticked; untick the ones
    /// you don't want. Types you do for the first time later follow "Other
    /// activities" instead.
    func adoptTypesDone() {
        filter.adopt(typesDone, included: true)
    }

    // MARK: - Syncing

    func syncNow() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        await SyncRunner.shared.syncNewActivities()
        await refresh()
    }

    /// Uploads `selected`. With `finishingSetup`, automatic syncing starts
    /// now and the home screen takes over.
    func importActivities(_ selected: [Workout], finishingSetup: Bool) async -> SyncReport? {
        guard !isSyncing, let engine = await SyncRunner.shared.currentEngine() else { return nil }
        isSyncing = true
        defer {
            isSyncing = false
            progress = nil
        }
        progress = (0, selected.count)
        var report: SyncReport?
        do {
            report = try await engine.importActivities(selected, finishingSetup: finishingSetup) { done, total in
                Task { @MainActor [weak self] in self?.progress = (done, total) }
            }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        await refresh()
        if finishingSetup, ledger.isSetUp {
            stage = .ready
            // Anything recorded while the import ran.
            await SyncRunner.shared.syncNewActivities()
            await refresh()
        }
        return report
    }

    /// Deletes these activities' records from the PDS.
    func remove(_ workoutIDs: [UUID]) async -> [UUID: String] {
        guard !isSyncing, let engine = await SyncRunner.shared.currentEngine() else { return [:] }
        isSyncing = true
        defer { isSyncing = false }
        var failed: [UUID: String] = [:]
        do {
            failed = try await engine.remove(workoutIDs)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        await refresh()
        return failed
    }
}
