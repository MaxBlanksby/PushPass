import Foundation
import SwiftData

struct RewardOutcome {
    let grantedMinutes: Int
    let explanation: String
}

enum RewardError: LocalizedError {
    case failedChallenge
    case duplicateReward
    case dailyLimitReached

    var errorDescription: String? {
        switch self {
        case .failedChallenge:
            "Only successful challenges can award time."
        case .duplicateReward:
            "This challenge has already been rewarded."
        case .dailyLimitReached:
            "You have reached today’s earning limit."
        }
    }
}

enum RewardService {
    @MainActor
    static func grantReward(
        for challenge: PushUpChallenge,
        preferences: UserPreferences,
        context: ModelContext,
        calendar: Calendar = .current
    ) throws -> RewardOutcome {
        guard challenge.wasSuccessful else { throw RewardError.failedChallenge }
        guard !challenge.wasRewarded else { throw RewardError.duplicateReward }

        let record = dailyRecord(for: .now, context: context, calendar: calendar)
        let remainingCapacity = max(0, preferences.maximumEarnedMinutesPerDay - record.minutesEarned)
        guard remainingCapacity > 0 else { throw RewardError.dailyLimitReached }

        let grantedMinutes = min(preferences.minutesPerChallenge, remainingCapacity)
        challenge.wasRewarded = true
        challenge.minutesAwarded = grantedMinutes
        record.minutesEarned += grantedMinutes
        record.pushUpsCompleted += challenge.completedRepetitions

        let activeSession = currentActiveSession(context: context)
        let sessionStart = Date.now
        let baseExpiration = activeSession?.expirationDate ?? sessionStart
        let newExpiration = max(baseExpiration, sessionStart).addingTimeInterval(TimeInterval(grantedMinutes * 60))

        if let activeSession {
            activeSession.expirationDate = newExpiration
            activeSession.minutesGranted += grantedMinutes
            activeSession.sourceChallengeID = challenge.id
        } else {
            let session = EarnedAccessSession(
                startDate: sessionStart,
                expirationDate: newExpiration,
                minutesGranted: grantedMinutes,
                sourceChallengeID: challenge.id
            )
            context.insert(session)
        }

        try context.save()

        let explanation: String
        if grantedMinutes < preferences.minutesPerChallenge {
            explanation = "Daily limit nearly reached. Awarded \(grantedMinutes) minutes instead of \(preferences.minutesPerChallenge)."
        } else {
            explanation = "Challenge complete. Awarded \(grantedMinutes) minutes."
        }

        return RewardOutcome(grantedMinutes: grantedMinutes, explanation: explanation)
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
}
