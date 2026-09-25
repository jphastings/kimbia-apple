import KimbiaKit
import SwiftUI

/// Chooses which kinds of activity sync.
///
/// Lists the types you've actually done, each with its own switch, then one
/// "Other activities" switch for everything else. Types you haven't done
/// yet can be added so they're allowed (or kept out) in advance.
struct ActivityPickerView: View {
    enum Mode {
        /// First run: leads on to the import screen.
        case setup
        /// From Settings: changes apply straight away.
        case edit
    }

    @Bindable var model: SyncModel
    let mode: Mode

    @State private var isAddingType = false
    /// The filter as it was when the screen opened, to spot types that
    /// have just been switched off but already have synced activities.
    @State private var original: ActivityFilter?

    private var typesDone: [ActivityType] { model.typesDone }

    /// Types with their own choice that haven't been done.
    private var chosenInAdvance: [ActivityType] {
        let done = Set(typesDone)
        return model.filter.choices.keys
            .filter { !done.contains($0) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Types just switched off that still have activities in Kimbia.
    private var switchedOffWithSyncedActivities: [ActivityType] {
        guard mode == .edit, let original else { return [] }
        let synced = model.syncedCounts
        return model.filter.newlyExcluded(since: original, among: synced.keys)
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        List {
            if !switchedOffWithSyncedActivities.isEmpty {
                alreadySyncedNotice
            }

            Section {
                if typesDone.isEmpty {
                    Text("No workouts in Apple Health yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(typesDone, id: \.self) { type in
                    ActivityToggle(model: model, type: type, detail: workoutCountText(type))
                }
            } header: {
                Text("Your Activities")
            } footer: {
                Text("Workouts of these kinds sync to Kimbia as soon as they're saved to Apple Health.")
            }

            Section {
                Toggle(isOn: $model.filter.includeOthers) {
                    Label("Other Activities", systemImage: "ellipsis.circle")
                }
                ForEach(chosenInAdvance, id: \.self) { type in
                    ActivityToggle(model: model, type: type, detail: String(localized: "Chosen in advance"))
                        .swipeActions {
                            Button(role: .destructive) {
                                model.filter.removeChoice(for: type)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                }
                Button {
                    isAddingType = true
                } label: {
                    Label("Choose Another Activity Type", systemImage: "plus")
                }
            } header: {
                Text("Everything Else")
            } footer: {
                Text("“Other Activities” covers every kind of activity not listed here, including ones you haven't tried yet. Add a type to decide for it in advance.")
            }
        }
        .navigationTitle("Activities to Sync")
        .toolbar {
            if mode == .setup {
                ToolbarItem(placement: .confirmationAction) {
                    NavigationLink("Next") {
                        ImportView(model: model, mode: .setup)
                    }
                }
            }
        }
        .sheet(isPresented: $isAddingType) {
            AddActivityTypeView(model: model)
        }
        .onAppear {
            if mode == .setup { model.adoptTypesDone() }
            if original == nil { original = model.filter }
        }
    }

    private var alreadySyncedNotice: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Label("Already-synced activities stay in Kimbia", systemImage: "info.circle")
                    .font(.headline)
                Text("Switching a type off only stops new workouts syncing. Those already synced (\(alreadySyncedSummary)) stay in Kimbia until you remove them.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
            NavigationLink {
                SyncedActivitiesView(model: model, highlighting: Set(switchedOffWithSyncedActivities))
            } label: {
                Text("Review and Remove…")
            }
        }
    }

    private var alreadySyncedSummary: String {
        let counts = model.syncedCounts
        return switchedOffWithSyncedActivities
            .map { type in "\(type.name): \(counts[type] ?? 0)" }
            .joined(separator: ", ")
    }

    private func workoutCountText(_ type: ActivityType) -> String {
        workoutCount(model.workoutCounts[type] ?? 0)
    }
}

/// A switch for one activity type, with its icon.
private struct ActivityToggle: View {
    @Bindable var model: SyncModel
    let type: ActivityType
    let detail: String

    var body: some View {
        Toggle(isOn: Binding(
            get: { model.filter.includes(type) },
            set: { model.filter.set(type, included: $0) }
        )) {
            Label {
                VStack(alignment: .leading) {
                    Text(type.name)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: type.symbolName)
                    .foregroundStyle(.tint)
            }
        }
    }
}

/// Picks a type you haven't done, to decide for it in advance.
struct AddActivityTypeView: View {
    @Bindable var model: SyncModel

    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var candidates: [ActivityType] {
        let done = Set(model.typesDone)
        return ActivityType.all.filter { type in
            !done.contains(type) && !model.filter.hasChoice(for: type)
                && (search.isEmpty || type.name.localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        NavigationStack {
            List(candidates, id: \.self) { type in
                Button {
                    // You'd only add a type to treat it differently from
                    // "Other Activities", so start it on the opposite setting.
                    model.filter.set(type, included: !model.filter.includeOthers)
                    dismiss()
                } label: {
                    Label(type.name, systemImage: type.symbolName)
                }
                .foregroundStyle(.primary)
            }
            .searchable(text: $search)
            .navigationTitle("Activity Types")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
