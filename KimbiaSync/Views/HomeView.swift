import KimbiaKit
import SwiftUI

/// How syncing is going, and your recent workouts with whether each went
/// to Kimbia.
struct HomeView: View {
    let model: SyncModel
    let account: AccountModel
    let session: Session

    @State private var isShowingSettings = false

    var body: some View {
        NavigationStack {
            List {
                statusSection
                Section("Recent Workouts") {
                    if model.recent.isEmpty {
                        Text("Workouts you record will appear here.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(model.recent) { workout in
                        HStack {
                            WorkoutRow(workout: workout)
                            Spacer()
                            syncState(for: workout)
                        }
                    }
                }
            }
            .navigationTitle("Kimbia Sync")
            .refreshable { await model.syncNow() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView(model: model, account: account, session: session)
            }
        }
    }

    private var statusSection: some View {
        Section {
            HStack {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.lastError == nil ? "Syncing Automatically" : "Sync Paused")
                        Text(statusDetail)
                            .font(.subheadline)
                            .foregroundStyle(model.lastError == nil ? Color.secondary : Color.red)
                    }
                } icon: {
                    Image(systemName: model.lastError == nil ? "checkmark.icloud" : "exclamationmark.icloud")
                        .foregroundStyle(model.lastError == nil ? Color.green : Color.orange)
                }
                Spacer()
                if model.isSyncing {
                    ProgressView()
                } else {
                    Button("Sync Now") {
                        Task { await model.syncNow() }
                    }
                    .buttonStyle(.bordered)
                }
            }
        } footer: {
            Text("New workouts sync when they're saved to Apple Health, even if this app isn't open.")
        }
    }

    private var statusDetail: String {
        if let error = model.lastError {
            return error
        }
        if let last = model.lastSuccessfulSync {
            return String(localized: "Last checked \(last.formatted(.relative(presentation: .named)))")
        }
        return String(localized: "Not checked yet")
    }

    @ViewBuilder
    private func syncState(for workout: Workout) -> some View {
        if model.isSynced(workout) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .accessibilityLabel("In Kimbia")
        } else if model.ledger.removed.contains(workout.id) {
            Image(systemName: "trash.circle")
                .foregroundStyle(.secondary)
                .accessibilityLabel("Removed from Kimbia")
        } else if let from = model.ledger.autoSyncFrom, workout.end <= from {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundStyle(.secondary)
                .accessibilityLabel("From before setup; not imported")
        } else if !model.filter.includes(workout.activityType) {
            Image(systemName: "minus.circle")
                .foregroundStyle(.secondary)
                .accessibilityLabel("Not synced: this activity type is switched off")
        } else {
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundStyle(.secondary)
                .accessibilityLabel("Waiting to sync")
        }
    }
}
