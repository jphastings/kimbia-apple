import KimbiaKit
import SwiftUI

/// Past workouts, each with a tick, to choose which to send to Kimbia.
///
/// Workouts matching your activity choices start ticked, so this screen
/// also shows what those choices mean for your history.
struct ImportView: View {
    enum Mode {
        /// First run: importing (or skipping) finishes setup.
        case setup
        /// From Settings: import anything not yet synced.
        case edit
    }

    let model: SyncModel
    let mode: Mode

    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<UUID> = []
    @State private var hasPreselected = false
    @State private var failures: [UUID: String] = [:]

    private var workouts: [Workout] { model.importable }

    private struct Month: Identifiable {
        let id: Date
        let workouts: [Workout]
    }

    /// Grouped by month, newest first.
    private var months: [Month] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: workouts) { workout in
            calendar.dateInterval(of: .month, for: workout.start)?.start ?? workout.start
        }
        return grouped.keys.sorted(by: >).map { Month(id: $0, workouts: grouped[$0]!) }
    }

    var body: some View {
        List {
            Section {
                Text(explanation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if workouts.isEmpty {
                Section {
                    Text("There's nothing to import.")
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(months) { month in
                Section(month.id.formatted(.dateTime.month(.wide).year())) {
                    ForEach(month.workouts) { workout in
                        row(for: workout)
                    }
                }
            }
        }
        .navigationTitle(mode == .setup ? "Import History" : "Import Past Activities")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Select All") { selected = Set(workouts.map(\.id)) }
                    Button("Select None") { selected = [] }
                    Button("Match Activity Choices") { selectMatchingFilter() }
                } label: {
                    Text("Select")
                }
                .disabled(model.isSyncing || workouts.isEmpty)
            }
        }
        .safeAreaInset(edge: .bottom) {
            importBar
        }
        .interactiveDismissDisabled(model.isSyncing)
        .navigationBarBackButtonHidden(model.isSyncing)
        .onAppear {
            guard !hasPreselected else { return }
            hasPreselected = true
            selectMatchingFilter()
        }
    }

    private var explanation: String {
        switch mode {
        case .setup:
            return String(localized: "Choose which past workouts to add to Kimbia. Ticked ones match the activities you chose to sync. From now on, new workouts sync automatically.")
        case .edit:
            return String(localized: "Workouts from before you set up Kimbia Sync, and ones you removed, that aren't in Kimbia.")
        }
    }

    private func row(for workout: Workout) -> some View {
        Button {
            if selected.contains(workout.id) {
                selected.remove(workout.id)
            } else {
                selected.insert(workout.id)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: selected.contains(workout.id) ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected.contains(workout.id) ? Color.accentColor : Color.secondary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    WorkoutRow(workout: workout)
                    if let failure = failures[workout.id] {
                        Text(failure)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .foregroundStyle(.primary)
        .disabled(model.isSyncing)
        .accessibilityAddTraits(selected.contains(workout.id) ? .isSelected : [])
    }

    private var importBar: some View {
        VStack(spacing: 8) {
            if let progress = model.progress {
                ProgressView(value: Double(progress.done), total: Double(max(progress.total, 1))) {
                    Text("Importing \(progress.done) of \(progress.total)…")
                        .font(.footnote)
                }
            } else if let error = model.lastError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
            Button {
                Task { await runImport() }
            } label: {
                Text(buttonTitle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(model.isSyncing || (mode == .edit && selected.isEmpty))
        }
        .padding()
        .background(.bar)
    }

    private var buttonTitle: String {
        if selected.isEmpty {
            return String(localized: "Skip and Finish")
        }
        let count = activityCount(selected.count)
        return mode == .setup ? String(localized: "Import \(count) and Finish") : String(localized: "Import \(count)")
    }

    private func selectMatchingFilter() {
        selected = Set(workouts.filter { model.filter.includes($0.activityType) }.map(\.id))
    }

    private func runImport() async {
        let chosen = workouts.filter { selected.contains($0.id) }
        guard let report = await model.importActivities(chosen, finishingSetup: mode == .setup) else { return }
        failures = report.failed
        selected.subtract(report.uploaded)
        if mode == .edit, report.failed.isEmpty {
            dismiss()
        }
    }
}
