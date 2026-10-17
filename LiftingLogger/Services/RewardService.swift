import Foundation
import SwiftData

struct RewardOutcome {
    let grantedSeconds: Int
    let explanation: String
}

enum RewardError: LocalizedError {
    case failedChallenge
    case duplicateReward
    case noRewardEarned
    case insufficientBalance
    case redemptionBelowMinimum(Int)

    var errorDescription: String? {
        switch self {
        case .failedChallenge:
            "Only successful push-up logs can award time."
        case .duplicateReward:
            "These push-ups have already been rewarded."
        case .noRewardEarned:
            "No verified push-ups were logged."
        case .insufficientBalance:
            "Not enough banked time is available."
        case .redemptionBelowMinimum(let seconds):
            "Redeem at least \(Self.formattedDuration(seconds)) at a time."
        }
    }

    private static func formattedDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60

        if minutes > 0, remainingSeconds > 0 {
            return "\(minutes)m \(remainingSeconds)s"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "\(remainingSeconds)s"
        }
    }
}

enum RewardService {
    @MainActor
    static func grantReward(
        for challenge: PushUpChallenge,
        context: ModelContext,
        calendar: Calendar = .current
    ) throws -> RewardOutcome {
        guard challenge.wasSuccessful else { throw RewardError.failedChallenge }
        guard !challenge.wasRewarded else { throw RewardError.duplicateReward }

        let transactions = (try? context.fetch(FetchDescriptor<WalletTransaction>())) ?? []
        guard !transactions.contains(where: { $0.relatedPushupSessionID == challenge.id && $0.type == .pushupsEarned }) else {
            challenge.wasRewarded = true
            try context.save()
            throw RewardError.duplicateReward
        }

        let economy = economySettings(context: context)
        let record = dailyRecord(for: .now, context: context, calendar: calendar)
        let grantedSeconds = max(0, challenge.completedRepetitions * economy.secondsPerPushup)
        guard grantedSeconds > 0 else { throw RewardError.noRewardEarned }
        let wallet = wallet(context: context)
        let maximumBankSeconds = economy.maximumBankSeconds ?? Int.max
        let newAvailableSeconds = min(maximumBankSeconds, wallet.availableSeconds + grantedSeconds)
        let actualGrantedSeconds = max(0, newAvailableSeconds - wallet.availableSeconds)

        challenge.wasRewarded = true
        challenge.minutesAwarded = actualGrantedSeconds / 60
        record.minutesEarned += actualGrantedSeconds / 60
        record.pushUpsCompleted += challenge.completedRepetitions

        wallet.availableSeconds = newAvailableSeconds
        wallet.lifetimeEarnedSeconds += actualGrantedSeconds
        wallet.updatedAt = .now

        let transaction = WalletTransaction(
            type: .pushupsEarned,
            seconds: actualGrantedSeconds,
            relatedPushupSessionID: challenge.id
        )
        context.insert(transaction)

        try context.save()

        return RewardOutcome(
            grantedSeconds: actualGrantedSeconds,
            explanation: "Logged \(challenge.completedRepetitions) push-ups. Banked \(formattedDuration(actualGrantedSeconds))."
        )
    }

    @MainActor
    static func redeem(seconds: Int, context: ModelContext) throws -> EarnedAccessSession {
        let economy = economySettings(context: context)
        guard seconds >= economy.minimumRedeemSeconds else {
            throw RewardError.redemptionBelowMinimum(economy.minimumRedeemSeconds)
        }

        let wallet = wallet(context: context)
        guard wallet.availableSeconds >= seconds else { throw RewardError.insufficientBalance }

        wallet.availableSeconds = max(0, wallet.availableSeconds - seconds)
        wallet.lifetimeSpentSeconds += seconds
        wallet.updatedAt = .now

        let sessionStart = Date.now
        let baseExpiration = currentActiveSession(context: context)?.expirationDate ?? sessionStart
        let newExpiration = max(baseExpiration, sessionStart).addingTimeInterval(TimeInterval(seconds))
        let minutesGranted = Int(ceil(Double(seconds) / 60.0))

        let session: EarnedAccessSession
        if let activeSession = currentActiveSession(context: context) {
            activeSession.expirationDate = newExpiration
            activeSession.minutesGranted += minutesGranted
            session = activeSession
        } else {
            session = EarnedAccessSession(
                startDate: sessionStart,
                expirationDate: newExpiration,
                minutesGranted: minutesGranted
            )
            context.insert(session)
        }

        let transaction = WalletTransaction(type: .timeRedeemed, seconds: seconds)
        context.insert(transaction)
        try context.save()

        return session
    }

    @MainActor
    static func expireFinishedSessions(context: ModelContext) {
        let now = Date.now
        let predicate = #Predicate<EarnedAccessSession> { session in
            session.isActive && session.expirationDate <= now
        }
        let descriptor = FetchDescriptor(predicate: predicate)
        guard let expiredSessions = try? context.fetch(descriptor), !expiredSessions.isEmpty else { return }

        for session in expiredSessions {
            session.isActive = false
        }

        try? context.save()
    }

    @MainActor
    static func dailyRecord(for date: Date, context: ModelContext, calendar: Calendar = .current) -> DailyRewardRecord {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
        let predicate = #Predicate<DailyRewardRecord> { record in
            record.date >= startOfDay && record.date < endOfDay
        }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1

        if let existing = try? context.fetch(descriptor).first {
            return existing
        }

        let record = DailyRewardRecord(date: startOfDay)
        context.insert(record)
        return record
    }

    @MainActor
    static func currentActiveSession(context: ModelContext) -> EarnedAccessSession? {
        let now = Date.now
        let predicate = #Predicate<EarnedAccessSession> { session in
            session.isActive && session.expirationDate > now
        }
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.expirationDate, order: .reverse)])
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    @MainActor
    static func wallet(context: ModelContext) -> TimeWallet {
        var descriptor = FetchDescriptor<TimeWallet>()
        descriptor.fetchLimit = 1

        if let existing = try? context.fetch(descriptor).first {
            return existing
        }

        let wallet = TimeWallet()
        context.insert(wallet)
        return wallet
    }

    @MainActor
    static func economySettings(context: ModelContext) -> PushupEconomySettings {
        var descriptor = FetchDescriptor<PushupEconomySettings>()
        descriptor.fetchLimit = 1

        if let existing = try? context.fetch(descriptor).first {
            if existing.secondsPerPushup == 15 {
                existing.secondsPerPushup = 60
                existing.updatedAt = .now
            }
            return existing
        }

        let settings = PushupEconomySettings()
        context.insert(settings)
        return settings
    }

    static func formattedDuration(_ seconds: Int) -> String {
        let clampedSeconds = max(0, seconds)
        let hours = clampedSeconds / 3600
        let minutes = (clampedSeconds % 3600) / 60
        let remainingSeconds = clampedSeconds % 60

        if hours > 0 {
            return remainingSeconds > 0 ? "\(hours)h \(minutes)m \(remainingSeconds)s" : "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return remainingSeconds > 0 ? "\(minutes)m \(remainingSeconds)s" : "\(minutes)m"
        } else {
            return "\(remainingSeconds)s"
        }
    }
}
