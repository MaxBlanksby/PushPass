import SwiftData
import SwiftUI

struct SettingsView: View {
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

                Section("Privacy & Safety") {
                    Text("PushPass is a fitness tracking and productivity app, not a medical service. Exercise within your abilities and stop if you experience pain, dizziness, or discomfort.")
                }
            }
            .navigationTitle("Settings")
            .onDisappear {
                try? modelContext.save()
            }
        }
    }
}

private struct PreferencesEditor: View {
    @Bindable var preferences: UserPreferences
    @AppStorage("appearanceMode") private var appearanceModeRawValue = AppAppearanceMode.light.rawValue

    var body: some View {
        Section("Appearance") {
            Picker("Color mode", selection: $appearanceModeRawValue) {
                ForEach(AppAppearanceMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode.rawValue)
                }
            }
            .pickerStyle(.segmented)
        }

        Section("Workout") {
            Picker("Weight unit", selection: $preferences.weightUnit) {
                ForEach(WeightUnit.allCases) { unit in
                    Text(unit.rawValue).tag(unit)
                }
            }
            Stepper("Default rest: \(preferences.defaultRestSeconds) sec", value: $preferences.defaultRestSeconds, in: 30...300, step: 15)
            Stepper("Rep range lower: \(preferences.preferredMinimumRepTarget)", value: $preferences.preferredMinimumRepTarget, in: 1...30)
                .onChange(of: preferences.preferredMinimumRepTarget) { _, newValue in
                    if newValue > preferences.preferredMaximumRepTarget {
                        preferences.preferredMaximumRepTarget = newValue
                    }
                }
            Stepper("Rep range upper: \(preferences.preferredMaximumRepTarget)", value: $preferences.preferredMaximumRepTarget, in: 1...50)
                .onChange(of: preferences.preferredMaximumRepTarget) { _, newValue in
                    if newValue < preferences.preferredMinimumRepTarget {
                        preferences.preferredMinimumRepTarget = newValue
                    }
                }
            Toggle("Progressive overload", isOn: $preferences.progressiveOverloadEnabled)
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [UserPreferences.self], inMemory: true)
}
