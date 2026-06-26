import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Screen Time") {
                    LabeledContent("Authorization", value: "Not requested")
                    LabeledContent("Restricted apps", value: "None")
                    LabeledContent("Base allowance", value: "0 min")
                }

                Section("Earn Time") {
                    LabeledContent("Push-ups per challenge", value: "\(AppConstants.Rewards.defaultPushUpsPerChallenge)")
                    LabeledContent("Minutes per challenge", value: "\(AppConstants.Rewards.defaultMinutesPerChallenge)")
                    LabeledContent("Daily earned limit", value: "\(AppConstants.Rewards.defaultMaximumEarnedMinutesPerDay) min")
                }

                Section("Workout") {
                    LabeledContent("Weight unit", value: "lb")
                    LabeledContent("Default rest timer", value: "90 sec")
                    LabeledContent("Progressive overload", value: "On")
                }

                Section("Privacy & Safety") {
                    Text("PushPass is a fitness tracking and productivity app, not a medical service. Exercise within your abilities and stop if you experience pain, dizziness, or discomfort.")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
