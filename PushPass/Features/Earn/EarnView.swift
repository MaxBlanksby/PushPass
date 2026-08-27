import SwiftData
import SwiftUI

#if canImport(FamilyControls)
import FamilyControls
#endif

struct EarnView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PushUpChallenge.startedAt, order: .reverse) private var challenges: [PushUpChallenge]
    @Query(sort: \DailyRewardRecord.date, order: .reverse) private var rewardRecords: [DailyRewardRecord]
    @Query(sort: \EarnedAccessSession.expirationDate, order: .reverse) private var sessions: [EarnedAccessSession]
    @Query private var wallets: [TimeWallet]
    @Query private var economySettings: [PushupEconomySettings]
    @Query(sort: \WalletTransaction.timestamp, order: .reverse) private var walletTransactions: [WalletTransaction]
    @State private var isShowingChallenge = false
    @State private var permissionErrorMessage: String?
    @State private var redemptionMessage: String?

    #if canImport(FamilyControls)
    @State private var restrictedSelection = ScreenTimeSetupService.storedSelection
    @State private var isShowingActivityPicker = false
    #endif

    private var activeSession: EarnedAccessSession? {
        sessions.first { $0.isActive && $0.expirationDate > .now }
    }

    private var activeSessionMinutesRemaining: Int {
        guard let activeSession else { return environment.dashboard.earnedMinutesAvailable }
        return Int(ceil(max(0, activeSession.expirationDate.timeIntervalSinceNow) / 60.0))
    }

    private var wallet: TimeWallet {
        wallets.first ?? TimeWallet()
    }

    private var economy: PushupEconomySettings {
        economySettings.first ?? PushupEconomySettings()
    }

    private var totalPushUps: Int {
        rewardRecords.map(\.pushUpsCompleted).reduce(0, +)
    }

    private var earnedSecondsToday: Int {
        walletTransactions
            .filter { $0.type == .pushupsEarned && Calendar.current.isDateInToday($0.timestamp) }
            .map(\.seconds)
            .reduce(0, +)
    }

    private var redemptionOptions: [Int] {
        [300, 600, 900].filter { $0 >= economy.minimumRedeemSeconds }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Current Reward Status") {
                    LabeledContent("Time bank", value: RewardService.formattedDuration(wallet.availableSeconds))
                    LabeledContent("Active access", value: "\(activeSessionMinutesRemaining) min")
                    LabeledContent("Earned today", value: RewardService.formattedDuration(earnedSecondsToday))
                    LabeledContent("Total push-ups", value: "\(totalPushUps)")
                    LabeledContent("Lifetime earned", value: RewardService.formattedDuration(wallet.lifetimeEarnedSeconds))
                    LabeledContent("Reward", value: "\(RewardService.formattedDuration(economy.secondsPerPushup)) per push-up")
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
                    Text("Do as many verified push-ups as you want, then log them into your time bank. Camera frames are processed on device and are not saved.")
                }

                Section {
                    if wallet.availableSeconds < economy.minimumRedeemSeconds {
                        ContentUnavailableView(
                            "No Redeemable Time Yet",
                            systemImage: "timer",
                            description: Text("Earn at least \(RewardService.formattedDuration(economy.minimumRedeemSeconds)) before redeeming.")
                        )
                    } else {
                        ForEach(redemptionOptions, id: \.self) { seconds in
                            Button {
                                redeem(seconds: seconds)
                            } label: {
                                Label("Use \(RewardService.formattedDuration(seconds))", systemImage: "play.circle")
                            }
                            .disabled(wallet.availableSeconds < seconds)
                        }
                    }

                    if let redemptionMessage {
                        Text(redemptionMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Redeem Banked Time")
                } footer: {
                    Text("V1 unlocks selected apps for the redeemed duration. The attached spec's app-usage-based consumption requires Device Activity and Shield extension targets, which are separate from this main app target.")
                }

                Section {
                    SetupStepRow(
                        number: 1,
                        title: "Start Setup",
                        details: [
                            "Tap Set Up Time Limits below.",
                            "PushPass will ask iOS for Screen Time permission so it can shield the apps you choose."
                        ]
                    )

                    SetupStepRow(
                        number: 2,
                        title: "Approve Permission",
                        details: [
                            "When the Apple Screen Time prompt appears, choose Allow.",
                            "If permission is denied, open Settings later and enable Screen Time access for PushPass."
                        ]
                    )

                    SetupStepRow(
                        number: 3,
                        title: "Pick Apps to Limit",
                        details: [
                            "Choose the apps, categories, or websites that should stay locked until you earn minutes.",
                            "Select only the apps you want PushPass to control, then tap Done."
                        ]
                    )

                    SetupStepRow(
                        number: 4,
                        title: "Earn Minutes",
                        details: [
                            "Tap Earn Minutes and let the camera count your push-ups.",
                            "When you are finished, tap Log. Each verified push-up adds \(RewardService.formattedDuration(economy.secondsPerPushup)) to your time bank."
                        ]
                    )

                    SetupStepRow(
                        number: 5,
                        title: "Redeem Banked Time",
                        details: [
                            "Choose Use 5 minutes, Use 10 minutes, or Use 15 minutes when you want access.",
                            "PushPass debits that time from your bank, unlocks selected apps, and shields them again when the active session ends."
                        ]
                    )

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
                } header: {
                    Text("Setup")
                } footer: {
                    Text("Screen Time setup must be completed on a real iPhone with Screen Time available. PushPass can only extend access for apps or categories selected during setup.")
                }

                Section("Previous Logs") {
                    if challenges.isEmpty {
                        ContentUnavailableView("No Push-Ups Logged Yet", systemImage: "figure.strengthtraining.traditional")
                    } else {
                        ForEach(challenges) { challenge in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(challenge.wasSuccessful ? "Logged Push-Ups" : "Push-Up Attempt")
                                    .font(.headline)
                                Text("\(challenge.completedRepetitions) push-ups · \(RewardService.formattedDuration(earnedSeconds(for: challenge)))")
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
            .task {
                _ = RewardService.wallet(context: modelContext)
                _ = RewardService.economySettings(context: modelContext)
                try? modelContext.save()
            }
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
            .alert("Screen Time Setup", isPresented: Binding(
                get: { permissionErrorMessage != nil },
                set: { if !$0 { permissionErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(permissionErrorMessage ?? "Open Settings to finish Screen Time setup.")
            }
        }
    }

    private func redeem(seconds: Int) {
        do {
            let session = try RewardService.redeem(seconds: seconds, context: modelContext)
            ScreenTimeSetupService.syncRestrictions(
                dashboard: environment.dashboard,
                accessExpirationDate: session.expirationDate
            )
            redemptionMessage = "Redeemed \(RewardService.formattedDuration(seconds)). Selected apps are available until \(session.expirationDate.formatted(date: .omitted, time: .shortened))."
        } catch {
            redemptionMessage = error.localizedDescription
        }
    }

    private func earnedSeconds(for challenge: PushUpChallenge) -> Int {
        if let transaction = walletTransactions.first(where: { $0.relatedPushupSessionID == challenge.id && $0.type == .pushupsEarned }) {
            return transaction.seconds
        }

        return challenge.completedRepetitions * economy.secondsPerPushup
    }
}

private struct SetupStepRow: View {
    let number: Int
    let title: String
    let details: [String]

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

                ForEach(details, id: \.self) { detail in
                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                        Text(detail)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    EarnView()
        .environment(AppEnvironment())
        .modelContainer(for: [UserPreferences.self, PushUpChallenge.self, DailyRewardRecord.self, EarnedAccessSession.self, TimeWallet.self, WalletTransaction.self, PushupEconomySettings.self], inMemory: true)
}
