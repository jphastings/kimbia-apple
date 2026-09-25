import KimbiaKit
import SwiftUI

struct SettingsView: View {
    let model: SyncModel
    let account: AccountModel
    let session: Session

    @Environment(\.dismiss) private var dismiss
    @State private var isConfirmingSignOut = false
    @State private var privacy = AppEnvironment.preferences.privacy

    var body: some View {
        NavigationStack {
            List {
                Section("Syncing") {
                    NavigationLink {
                        ActivityPickerView(model: model, mode: .edit)
                    } label: {
                        Label("Activities to Sync", systemImage: "figure.run")
                    }
                    NavigationLink {
                        ImportView(model: model, mode: .edit)
                    } label: {
                        LabeledContent {
                            Text("\(model.importable.count)")
                        } label: {
                            Label("Import Past Activities", systemImage: "clock.arrow.circlepath")
                        }
                    }
                    NavigationLink {
                        SyncedActivitiesView(model: model, highlighting: [])
                    } label: {
                        LabeledContent {
                            Text("\(model.ledger.synced.count)")
                        } label: {
                            Label("Synced Activities", systemImage: "checkmark.icloud")
                        }
                    }
                }

                Section {
                    Toggle("Exact Start Times", isOn: $privacy.shareExactTimes)
                    Picker("Route Map", selection: $privacy.route) {
                        Text("Hidden").tag(KimbiaPrivacy.Route.hidden)
                        Text("Cropped").tag(KimbiaPrivacy.Route.cropped)
                        Text("Full").tag(KimbiaPrivacy.Route.full)
                    }
                } header: {
                    Text("What's Public")
                } footer: {
                    Text(privacyExplanation)
                }
                .onChange(of: privacy) { _, newValue in
                    AppEnvironment.preferences.privacy = newValue
                }

                Section {
                    LabeledContent("Signed in as", value: session.handle.map { "@\($0)" } ?? session.did)
                    LabeledContent("Data server", value: session.pdsURL.host() ?? session.pdsURL.absoluteString)
                    Button("Sign Out", role: .destructive) {
                        isConfirmingSignOut = true
                    }
                    .disabled(account.isSigningOut)
                } header: {
                    Text("Account")
                } footer: {
                    if let error = account.error {
                        Text(error).foregroundStyle(.red)
                    }
                }

                Section {
                    Link(destination: URL(string: "https://kimbia-sync.byjp.me/privacy.html")!) {
                        Label("Privacy", systemImage: "hand.raised")
                    }
                    Link(destination: URL(string: "https://github.com/jphastings/kimbia-apple")!) {
                        Label("Source Code", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                } footer: {
                    Text("Kimbia Sync \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "") is an independent app, not made by Kimbia.")
                }
            }
            .navigationTitle("Settings")
            .onAppear { privacy = AppEnvironment.preferences.privacy }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Sign out?", isPresented: $isConfirmingSignOut, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) {
                    Task { await account.signOut() }
                }
            } message: {
                Text("New workouts will stop syncing. Activities already in Kimbia stay there.")
            }
        }
    }

    private var privacyExplanation: String {
        let time = privacy.shareExactTimes
            ? String(localized: "Activities show when they started and how long they took, stops included.")
            : String(localized: "Activities show only the day they happened.")
        let route: String
        switch privacy.route {
        case .hidden: route = String(localized: "No map is shared.")
        case .cropped: route = String(localized: "Maps leave out the first and last 500 m, so they don't show where you start or finish.")
        case .full: route = String(localized: "Maps show the whole route, including where you start and finish.")
        }
        return time + " " + route + " " + String(localized: "Activities in your data server are public. Changes apply to activities synced from now on.")
    }
}
