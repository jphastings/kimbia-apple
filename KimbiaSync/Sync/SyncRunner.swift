import Foundation
import KimbiaKit

/// The single way into syncing, used by the UI, HealthKit background
/// delivery and background app refresh alike. Keeping one `SyncEngine` per
/// account here is what stops a background wake-up racing a sync the person
/// started by hand.
actor SyncRunner {
    static let shared = SyncRunner()

    private var engine: (did: String, engine: SyncEngine)?

    /// The engine for the signed-in account, or `nil` when signed out.
    func currentEngine() -> SyncEngine? {
        guard let session = try? AppEnvironment.sessionStore.load() else {
            engine = nil
            return nil
        }
        if let engine, engine.did == session.did {
            return engine.engine
        }
        let fresh = SyncEngine(
            did: session.did,
            source: HealthKitWorkoutSource.shared,
            writer: AppEnvironment.makePDSClient(session: session),
            mapper: KimbiaActivityMapper(
                privacy: { AppEnvironment.preferences.privacy },
                routes: HealthKitWorkoutSource.shared
            ),
            ledgerStore: AppEnvironment.ledgerStore
        )
        engine = (session.did, fresh)
        return fresh
    }

    /// Forgets the engine, so the next sync starts from the stored session.
    /// Called on sign-in and sign-out.
    func reset() {
        engine = nil
    }

    /// Syncs new activities with the saved filter, recording the outcome for
    /// the UI to show. Never throws: a background caller has nobody to tell.
    @discardableResult
    func syncNewActivities() async -> SyncReport? {
        guard let engine = currentEngine() else { return nil }
        let preferences = AppEnvironment.preferences
        do {
            let report = try await engine.syncNewActivities(filter: preferences.filter)
            preferences.lastSuccessfulSync = Date()
            preferences.lastSyncError = nil
            return report
        } catch is CancellationError {
            return nil
        } catch {
            preferences.lastSyncError = error.localizedDescription
            if (error as? OAuthError) == .sessionExpired {
                reset()
            }
            return nil
        }
    }
}
