import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var preferences: [UserPreferences]

    private var prefs: UserPreferences {
        if let existing = preferences.first {
            return existing
        }
        let created = UserPreferences()
        modelContext.insert(created)
        return created
    }

    var body: some View {
        NavigationStack {
            List {
                PreferencesEditor(preferences: prefs)

                Section {
                    LabeledContent("Authorization", value: "Not requested")
                    LabeledContent("Restricted apps", value: "None")
                    LabeledContent("Base allowance", value: "\(prefs.baseDailyMinutes) min")
                } header: {
                    Text("Screen Time")
                } footer: {
                    Text("Family Controls, app selection, shields, App Group storage, and DeviceActivity extensions still require Xcode capability setup and real-device testing.")
                }

                Section("Camera") {
                    Text("PushPass uses the camera to detect body position and count push-ups. Camera frames are processed on your device and are not saved.")
                }

                Section("Privacy & Safety") {
                    Text("PushPass is a fitness tracking and productivity app, not a medical service. Exercise within your abilities and stop if you experience pain, dizziness, or discomfort.")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct PreferencesEditor: View {
    @Bindable var preferences: UserPreferences

    var body: some View {
        Section("Earn Time") {
            Stepper("Push-ups per challenge: \(preferences.pushUpsPerChallenge)", value: $preferences.pushUpsPerChallenge, in: 1...100)
            Stepper("Minutes per challenge: \(preferences.minutesPerChallenge)", value: $preferences.minutesPerChallenge, in: 1...60)
            Stepper("Daily earned limit: \(preferences.maximumEarnedMinutesPerDay) min", value: $preferences.maximumEarnedMinutesPerDay, in: 5...240, step: 5)
        }

        Section("Workout") {
            Picker("Weight unit", selection: $preferences.weightUnit) {
                ForEach(WeightUnit.allCases) { unit in
                    Text(unit.rawValue).tag(unit)
                }
            }
            Stepper("Default rest: \(preferences.defaultRestSeconds) sec", value: $preferences.defaultRestSeconds, in: 30...300, step: 15)
            Toggle("Progressive overload", isOn: $preferences.progressiveOverloadEnabled)
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [UserPreferences.self], inMemory: true)
}
