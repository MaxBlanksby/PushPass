import Foundation
import SwiftData

struct RewardOutcome {
    let grantedMinutes: Int
    let explanation: String
}

enum RewardError: LocalizedError {
    case failedChallenge
    case duplicateReward

    var errorDescription: String? {
        switch self {
        case .failedChallenge:
            "Only successful push-up logs can award time."
        case .duplicateReward:
            "These push-ups have already been rewarded."
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

        let record = dailyRecord(for: .now, context: context, calendar: calendar)
        let grantedMinutes = max(0, challenge.completedRepetitions)

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

        return RewardOutcome(
            grantedMinutes: grantedMinutes,
            explanation: "Logged \(challenge.completedRepetitions) push-ups. Awarded \(grantedMinutes) minutes."
        )
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
}
