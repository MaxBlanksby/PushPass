import SwiftData
import SwiftUI

struct EarnView: View {
    @Environment(AppEnvironment.self) private var environment
    @Query private var preferences: [UserPreferences]
    @Query(sort: \PushUpChallenge.startedAt, order: .reverse) private var challenges: [PushUpChallenge]
    @Query(sort: \DailyRewardRecord.date, order: .reverse) private var rewardRecords: [DailyRewardRecord]
    @Query(sort: \EarnedAccessSession.expirationDate, order: .reverse) private var sessions: [EarnedAccessSession]
    @State private var isShowingChallenge = false

    private var prefs: UserPreferences {
        preferences.first ?? UserPreferences()
    }

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

    var body: some View {
        NavigationStack {
            List {
                Section("Current Reward Status") {
                    LabeledContent("Earned minutes available", value: "\(activeSessionMinutesRemaining) min")
                    LabeledContent("Earned today", value: "\(todayRecord?.minutesEarned ?? 0) min")
                    LabeledContent("Daily limit", value: "\(prefs.maximumEarnedMinutesPerDay) min")
                    LabeledContent("Next challenge", value: "\(prefs.pushUpsPerChallenge) push-ups")
                    LabeledContent("Reward", value: "1 min per push-up")
                    if let activeSession {
                        LabeledContent("Access expires", value: activeSession.expirationDate.formatted(date: .omitted, time: .shortened))
                    }
                }

                Section {
                    Button {
                        isShowingChallenge = true
                    } label: {
                        Label("Begin Challenge", systemImage: "camera.fill")
                    }
                } footer: {
                    Text("Camera frames are processed on device and are not saved. In debug builds, Simulate Rep is available for simulator testing.")
                }

                Section("Previous Challenges") {
                    if challenges.isEmpty {
                        ContentUnavailableView("No Challenges Yet", systemImage: "figure.strengthtraining.traditional")
                    } else {
                        ForEach(challenges) { challenge in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(challenge.wasSuccessful ? "Completed Challenge" : "Challenge Attempt")
                                    .font(.headline)
                                Text("\(challenge.completedRepetitions) / \(challenge.targetRepetitions) push-ups · \(challenge.minutesAwarded) min")
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
                PushUpChallengeView(targetRepetitions: prefs.pushUpsPerChallenge)
            }
        }
    }
}

#Preview {
    EarnView()
        .environment(AppEnvironment())
        .modelContainer(for: [UserPreferences.self, PushUpChallenge.self, DailyRewardRecord.self, EarnedAccessSession.self], inMemory: true)
}
