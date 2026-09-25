import KimbiaKit
import SwiftUI

struct SettingsView: View {
    let model: SyncModel
    let account: AccountModel
    let session: Session

    @Environment(\.dismiss) private var dismiss
    @State private var isConfirmingSignOut = false

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
}
