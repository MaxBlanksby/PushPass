import SwiftData
import SwiftUI

#if canImport(FamilyControls)
import FamilyControls
#endif

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var modelContext
    @Query private var preferences: [UserPreferences]
    @Query(sort: \EarnedAccessSession.expirationDate, order: .reverse) private var sessions: [EarnedAccessSession]
    @State private var permissionErrorMessage: String?

    #if canImport(FamilyControls)
    @State private var restrictedSelection = ScreenTimeSetupService.storedSelection
    @State private var isShowingActivityPicker = false
    #endif

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
                    LabeledContent("Authorization", value: environment.dashboard.isScreenTimeAuthorized ? "Granted" : "Needed")
                    LabeledContent("Restricted apps", value: environment.dashboard.hasRestrictedSelection ? "Selected" : "None")
                    LabeledContent("Base allowance", value: "\(prefs.baseDailyMinutes) min")

                    Button {
                        Task {
                            permissionErrorMessage = await ScreenTimeSetupService.requestAuthorizationIfNeeded(for: environment.dashboard)

                            #if canImport(FamilyControls)
                            if environment.dashboard.isScreenTimeAuthorized {
                                isShowingActivityPicker = true
                            }
                            #endif
                        }
                    } label: {
                        Label("Set Up Time Control", systemImage: "hourglass.badge.shield.checkmark")
                    }
                } header: {
                    Text("Screen Time")
                } footer: {
                    Text("Family Controls authorization and app selection require the Family Controls capability and real-device testing.")
                }

                Section("Camera") {
                    Text("PushPass uses the camera to detect body position and count push-ups. Camera frames are processed on your device and are not saved.")
                }

                Section("Privacy & Safety") {
                    Text("PushPass is a fitness tracking and productivity app, not a medical service. Exercise within your abilities and stop if you experience pain, dizziness, or discomfort.")
                }
            }
            .navigationTitle("Settings")
            .task {
                syncRestrictions()
            }
            #if canImport(FamilyControls)
            .sheet(isPresented: $isShowingActivityPicker) {
                NavigationStack {
                    FamilyActivityPicker(selection: $restrictedSelection)
                        .navigationTitle("Choose Apps")
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") {
                                    isShowingActivityPicker = false
                                }
                            }
                        }
                }
            }
            .onChange(of: restrictedSelection) { _, newSelection in
                ScreenTimeSetupService.store(selection: newSelection, dashboard: environment.dashboard)
                syncRestrictions()
            }
            #endif
            .alert("Screen Time Setup Needed", isPresented: Binding(
                get: { permissionErrorMessage != nil },
                set: { if !$0 { permissionErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(permissionErrorMessage ?? "Open Settings to finish Screen Time setup.")
            }
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

    private var activeAccessExpirationDate: Date? {
        sessions.first { $0.isActive && $0.expirationDate > .now }?.expirationDate
    }

    private func syncRestrictions() {
        RewardService.expireFinishedSessions(context: modelContext)
        ScreenTimeSetupService.syncRestrictions(
            dashboard: environment.dashboard,
            accessExpirationDate: activeAccessExpirationDate
        )
    }
}

private struct PreferencesEditor: View {
    @Bindable var preferences: UserPreferences

    var body: some View {
        Section("Earn Time") {
            LabeledContent("Reward", value: "1 min per push-up")
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
        .environment(AppEnvironment())
        .modelContainer(for: [UserPreferences.self, EarnedAccessSession.self], inMemory: true)
}
