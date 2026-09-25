import KimbiaKit
import SwiftUI

/// Everything this app has written to your data server, by activity type,
/// with a way to remove any of it.
struct SyncedActivitiesView: View {
    let model: SyncModel
    /// Types to list first and pre-select, e.g. ones just switched off.
    let highlighting: Set<ActivityType>

    @State private var selection: Set<UUID> = []
    @State private var editMode: EditMode = .inactive
    @State private var isConfirming = false
    @State private var failures: [UUID: String] = [:]
    @State private var hasPreselected = false

    private struct TypeGroup: Identifiable {
        let type: ActivityType
        let entries: [SyncedActivity]
        var id: ActivityType { type }
    }

    private var groups: [TypeGroup] {
        let grouped = Dictionary(grouping: model.ledger.synced.values, by: \.activityType)
        return grouped.keys
            .sorted { a, b in
                let aFirst = highlighting.contains(a), bFirst = highlighting.contains(b)
                if aFirst != bFirst { return aFirst }
                return a.name.localizedStandardCompare(b.name) == .orderedAscending
            }
            .map { type in TypeGroup(type: type, entries: grouped[type]!.sorted { $0.start > $1.start }) }
    }

    var body: some View {
        List(selection: $selection) {
            if groups.isEmpty {
                Text("Nothing has been synced yet.")
                    .foregroundStyle(.secondary)
            }
            ForEach(groups) { group in
                Section {
                    ForEach(group.entries, id: \.workoutID) { entry in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.start.formatted(date: .abbreviated, time: .shortened))
                            if let failure = failures[entry.workoutID] {
                                Text(failure)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                } header: {
                    HStack {
                        Label(group.type.name, systemImage: group.type.symbolName)
                        Spacer()
                        if editMode.isEditing {
                            Button("Select All") {
                                selection.formUnion(group.entries.map(\.workoutID))
                            }
                            .font(.footnote)
                            .textCase(nil)
                        }
                    }
                } footer: {
                    Text(activityCount(group.entries.count))
                }
            }
        }
        .environment(\.editMode, $editMode)
        .navigationTitle("Synced Activities")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(editMode.isEditing ? "Done" : "Select") {
                    editMode = editMode.isEditing ? .inactive : .active
                    if !editMode.isEditing { selection = [] }
                }
                .disabled(model.isSyncing || groups.isEmpty)
            }
            if editMode.isEditing {
                ToolbarItem(placement: .bottomBar) {
                    Button("Remove \(activityCount(selection.count)) from Kimbia", role: .destructive) {
                        isConfirming = true
                    }
                    .disabled(selection.isEmpty || model.isSyncing)
                }
            }
        }
        .overlay {
            if model.isSyncing { ProgressView() }
        }
        .confirmationDialog("Remove \(activityCount(selection.count)) from Kimbia?", isPresented: $isConfirming, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                Task { await removeSelected() }
            }
        } message: {
            Text("They'll be deleted from your data server. The workouts stay in Apple Health, and you can import them again later.")
        }
        .onAppear {
            guard !hasPreselected, !highlighting.isEmpty else { return }
            hasPreselected = true
            selection = Set(model.ledger.synced.values.filter { highlighting.contains($0.activityType) }.map(\.workoutID))
            editMode = .active
        }
    }

    private func removeSelected() async {
        failures = await model.remove(Array(selection))
        selection = Set(failures.keys)
        if selection.isEmpty { editMode = .inactive }
    }
}
