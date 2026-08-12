import SwiftData
import SwiftUI

#if canImport(FamilyControls)
import FamilyControls
#endif

struct EarnView: View {
    @Environment(AppEnvironment.self) private var environment
    @Query(sort: \PushUpChallenge.startedAt, order: .reverse) private var challenges: [PushUpChallenge]
    @Query(sort: \DailyRewardRecord.date, order: .reverse) private var rewardRecords: [DailyRewardRecord]
    @Query(sort: \EarnedAccessSession.expirationDate, order: .reverse) private var sessions: [EarnedAccessSession]
    @State private var isShowingChallenge = false
    @State private var permissionErrorMessage: String?

    #if canImport(FamilyControls)
    @State private var restrictedSelection = ScreenTimeSetupService.storedSelection
    @State private var isShowingActivityPicker = false
    #endif

    private var todayRecord: DailyRewardRecord? {
        rewardRecords.first { Calendar.current.isDateInToday($0.date) }
    }

    private var activeSession: EarnedAccessSession? {
        sessions.first { $0.isActive && $0.expirationDate > .now }
    }

    private var activeSessionMinutesRemaining: Int {
        guard let activeSession else { return environment.dashboard.earnedMinutesAvailable }
        return Int(ceil(max(0, activeSession.expirationDate.timeIntervalSinceNow) / 60.0))
    }

    private var totalPushUps: Int {
        rewardRecords.map(\.pushUpsCompleted).reduce(0, +)
    }

    private var totalMinutesEarned: Int {
        rewardRecords.map(\.minutesEarned).reduce(0, +)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Current Reward Status") {
                    LabeledContent("Earned minutes available", value: "\(activeSessionMinutesRemaining) min")
                    LabeledContent("Earned today", value: "\(todayRecord?.minutesEarned ?? 0) min")
                    LabeledContent("Total push-ups", value: "\(totalPushUps)")
                    LabeledContent("Total minutes earned", value: "\(totalMinutesEarned) min")
                    LabeledContent("Reward", value: "1 min per push-up")
                    if let activeSession {
                        LabeledContent("Access expires", value: activeSession.expirationDate.formatted(date: .omitted, time: .shortened))
                    }
                }

                Section {
                    Button {
                        isShowingChallenge = true
                    } label: {
                        Label("Earn Minutes", systemImage: "camera.fill")
                    }
                } footer: {
                    Text("Do as many verified push-ups as you want, then log them. Camera frames are processed on device and are not saved.")
                }

                Section("Setup") {
                    SetupStepRow(number: 1, title: "Allow Screen Time", detail: "Grant PushPass permission to manage app limits.")
                    SetupStepRow(number: 2, title: "Choose Limited Apps", detail: "Pick the apps or categories PushPass should lock until minutes are earned.")
                    SetupStepRow(number: 3, title: "Earn and Extend", detail: "Each logged push-up adds one minute to the current access window.")

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
                        Label("Set Up Time Limits", systemImage: "hourglass.badge.shield.checkmark")
                    }

                    LabeledContent("Authorization", value: environment.dashboard.isScreenTimeAuthorized ? "Granted" : "Needed")
                    LabeledContent("Limited apps", value: environment.dashboard.hasRestrictedSelection ? "Selected" : "None")
                }

                Section("Previous Logs") {
                    if challenges.isEmpty {
                        ContentUnavailableView("No Push-Ups Logged Yet", systemImage: "figure.strengthtraining.traditional")
                    } else {
                        ForEach(challenges) { challenge in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(challenge.wasSuccessful ? "Logged Push-Ups" : "Push-Up Attempt")
                                    .font(.headline)
                                Text("\(challenge.completedRepetitions) push-ups · \(challenge.minutesAwarded) min")
                                    .foregroundStyle(.secondary)
                                Text(challenge.startedAt, format: .dateTime.month().day().hour().minute())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Earn")
            .navigationDestination(isPresented: $isShowingChallenge) {
                PushUpChallengeView()
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
        }
    }
}

private struct SetupStepRow: View {
    let number: Int
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(.blue)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    EarnView()
        .environment(AppEnvironment())
        .modelContainer(for: [UserPreferences.self, PushUpChallenge.self, DailyRewardRecord.self, EarnedAccessSession.self], inMemory: true)
}
