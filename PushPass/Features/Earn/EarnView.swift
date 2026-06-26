import SwiftUI

struct EarnView: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        NavigationStack {
            List {
                Section("Current Reward Status") {
                    LabeledContent("Earned minutes available", value: "\(environment.dashboard.earnedMinutesAvailable) min")
                    LabeledContent("Earned today", value: "0 min")
                    LabeledContent("Daily limit", value: "\(AppConstants.Rewards.defaultMaximumEarnedMinutesPerDay) min")
                    LabeledContent("Next challenge", value: "\(AppConstants.Rewards.defaultPushUpsPerChallenge) push-ups")
                    LabeledContent("Reward", value: "\(AppConstants.Rewards.defaultMinutesPerChallenge) min")
                }

                Section {
                    Button {
                    } label: {
                        Label("Begin Challenge", systemImage: "camera.fill")
                    }
                    .disabled(true)
                } footer: {
                    Text("Camera-based verification is scheduled for the AVFoundation and Vision phases. This button is disabled until that service exists.")
                }

                Section("Previous Challenges") {
                    ContentUnavailableView("No Challenges Yet", systemImage: "figure.strengthtraining.traditional")
                }
            }
            .navigationTitle("Earn")
        }
    }
}

#Preview {
    EarnView()
        .environment(AppEnvironment())
}
