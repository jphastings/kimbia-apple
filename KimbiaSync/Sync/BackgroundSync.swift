import BackgroundTasks
import HealthKit
import KimbiaKit
import os

/// Keeps syncing while the app isn't open.
///
/// Two triggers, both ending in `SyncRunner.syncNewActivities()`:
/// - HealthKit background delivery wakes the app as soon as a workout is
///   saved to Health. This is the main one.
/// - A background app refresh task, as a safety net for wake-ups iOS
///   dropped or deferred (e.g. a workout saved while the phone was locked,
///   when Health data can't be read).
enum BackgroundSync {
    private static let logger = Logger(subsystem: "me.byjp.KimbiaSync", category: "BackgroundSync")

    /// Only ever touched on the main thread, at launch or after the Health
    /// permission sheet.
    private static var isObserving = false

    /// Must be called before the app finishes launching.
    static func registerRefreshTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: AppEnvironment.refreshTaskIdentifier, using: nil) { task in
            handle(task as! BGAppRefreshTask)
        }
    }

    /// Asks iOS to wake the app in a few hours. iOS decides the actual time.
    static func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: AppEnvironment.refreshTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 4 * 60 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            logger.error("Couldn't schedule background refresh: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func handle(_ task: BGAppRefreshTask) {
        scheduleRefresh()
        let work = Task {
            await SyncRunner.shared.syncNewActivities()
            task.setTaskCompleted(success: !Task.isCancelled)
        }
        task.expirationHandler = { work.cancel() }
    }

    /// Starts listening for new workouts. HealthKit forgets observer queries
    /// when the app is terminated, so this runs on every launch; background
    /// delivery itself persists until disabled.
    static func observeWorkouts() {
        guard !isObserving else { return }
        isObserving = true
        let store = HealthKitWorkoutSource.shared.store
        let query = HKObserverQuery(sampleType: .workoutType(), predicate: nil) { _, completionHandler, error in
            if let error {
                logger.error("Workout observer failed: \(error.localizedDescription, privacy: .public)")
                completionHandler()
                return
            }
            Task {
                await SyncRunner.shared.syncNewActivities()
                // HealthKit backs off if this isn't called promptly.
                completionHandler()
            }
        }
        store.execute(query)
        store.enableBackgroundDelivery(for: .workoutType(), frequency: .immediate) { success, error in
            if !success {
                logger.error("Couldn't enable background delivery: \(error?.localizedDescription ?? "unknown", privacy: .public)")
            }
        }
    }
}
