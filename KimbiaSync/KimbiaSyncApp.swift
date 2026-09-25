import KimbiaKit
import SwiftUI
import UIKit

@main
struct KimbiaSyncApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var account: AccountModel

    init() {
        // Must run before `AccountModel` reads the session.
        clearSessionOnFreshInstall(store: AppEnvironment.sessionStore, defaults: AppEnvironment.preferences.defaultsForFreshInstallCheck)
        _account = State(initialValue: AccountModel())
    }

    var body: some Scene {
        WindowGroup {
            RootView(account: account)
        }
    }
}

/// Background work has to be registered while the app is launching, which
/// may be in the background with no UI at all (a HealthKit wake-up).
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        BackgroundSync.registerRefreshTask()
        if HealthKitWorkoutSource.isAvailable {
            BackgroundSync.observeWorkouts()
        }
        BackgroundSync.scheduleRefresh()
        return true
    }
}

/// Signed out → sign in. Signed in → the synced app.
struct RootView: View {
    let account: AccountModel

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if let session = account.session {
                SignedInRoot(account: account, session: session)
                    .id(session.did)
            } else {
                SignInView(account: account)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { account.reload() }
        }
    }
}

/// Health access → choose activities and import → home.
struct SignedInRoot: View {
    let account: AccountModel
    let session: Session

    @State private var model = SyncModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch model.stage {
            case .loading:
                ProgressView()
            case .needsHealthAccess:
                HealthAccessView(model: model)
            case .settingUp:
                NavigationStack {
                    ActivityPickerView(model: model, mode: .setup)
                }
            case .ready:
                HomeView(model: model, account: account, session: session)
            }
        }
        .task { await model.load() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, model.stage == .ready else { return }
            Task { await model.syncNow() }
        }
    }
}
