import AuthenticationServices
import SwiftUI

/// The first screen: what the app does, and a handle field.
struct SignInView: View {
    let account: AccountModel

    @Environment(\.webAuthenticationSession) private var webAuthenticationSession
    @State private var handle = ""
    @FocusState private var isHandleFocused: Bool

    private var canSubmit: Bool {
        !handle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !account.isSigningIn
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "figure.run.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.tint)
                            .accessibilityHidden(true)
                        Text("Kimbia Sync")
                            .font(.largeTitle.bold())
                        Text("Sends the workouts you record in Apple Health to your Kimbia training journal, automatically.")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)

                Section {
                    TextField("you.bsky.social", text: $handle)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                        .textContentType(.username)
                        .submitLabel(.go)
                        .focused($isHandleFocused)
                        .onSubmit(submit)
                        .accessibilityLabel("Your handle")
                } header: {
                    Text("Your handle")
                } footer: {
                    if let error = account.error {
                        Text(error).foregroundStyle(.red)
                    } else {
                        Text("Sign in with the atmosphere account you use for Kimbia. Your activities are written straight to your own data server.")
                    }
                }

                Section {
                    Button(action: submit) {
                        HStack {
                            Spacer()
                            if account.isSigningIn {
                                ProgressView()
                            } else {
                                Text("Sign In").bold()
                            }
                            Spacer()
                        }
                    }
                    .disabled(!canSubmit)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private func submit() {
        guard canSubmit else { return }
        isHandleFocused = false
        let browser = webAuthenticationSession
        let model = account
        let typedHandle = handle
        Task {
            await model.signIn(account: typedHandle, using: browser)
        }
    }
}
