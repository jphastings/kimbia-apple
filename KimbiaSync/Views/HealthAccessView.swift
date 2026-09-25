import SwiftUI

/// Explains why the app needs Health and asks for it.
struct HealthAccessView: View {
    let model: SyncModel

    @State private var isAsking = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 72))
                .foregroundStyle(.pink)
                .accessibilityHidden(true)
            VStack(spacing: 12) {
                Text("Read Your Workouts")
                    .font(.title.bold())
                Text("Kimbia Sync reads your workouts from Apple Health, along with their distance, energy, heart rate and route, so it can add them to your training journal. It never writes to Health.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            if !HealthKitWorkoutSource.isAvailable {
                Text("Apple Health isn't available on this device.")
                    .foregroundStyle(.red)
            }
            Spacer()
            Button {
                isAsking = true
                Task {
                    await model.requestHealthAccess()
                    isAsking = false
                }
            } label: {
                Group {
                    if isAsking {
                        ProgressView()
                    } else {
                        Text("Continue")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isAsking || !HealthKitWorkoutSource.isAvailable)
        }
        .padding(24)
    }
}
