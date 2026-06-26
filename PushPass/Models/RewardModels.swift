import Foundation
import SwiftData

@Model
final class PushUpChallenge {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var completedAt: Date?
    var targetRepetitions: Int
    var completedRepetitions: Int
    var minutesAwarded: Int
    var wasSuccessful: Bool
    var failureReason: String?
    var detectionMode: String
    var wasRewarded: Bool

    init(
        id: UUID = UUID(),
        startedAt: Date = .now,
        completedAt: Date? = nil,
        targetRepetitions: Int,
        completedRepetitions: Int = 0,
        minutesAwarded: Int = 0,
        wasSuccessful: Bool = false,
        failureReason: String? = nil,
        detectionMode: String = "camera",
        wasRewarded: Bool = false
    ) {
        self.id = id
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.targetRepetitions = targetRepetitions
        self.completedRepetitions = completedRepetitions
        self.minutesAwarded = minutesAwarded
        self.wasSuccessful = wasSuccessful
        self.failureReason = failureReason
        self.detectionMode = detectionMode
        self.wasRewarded = wasRewarded
    }
}

@Model
final class DailyRewardRecord {
    @Attribute(.unique) var id: UUID
    var date: Date
    var pushUpsCompleted: Int
    var minutesEarned: Int
    var minutesUsed: Int

    init(
        id: UUID = UUID(),
        date: Date,
        pushUpsCompleted: Int = 0,
        minutesEarned: Int = 0,
        minutesUsed: Int = 0
    ) {
        self.id = id
        self.date = date
        self.pushUpsCompleted = pushUpsCompleted
        self.minutesEarned = minutesEarned
        self.minutesUsed = minutesUsed
    }
}

@Model
final class EarnedAccessSession {
    @Attribute(.unique) var id: UUID
    var startDate: Date
    var expirationDate: Date
    var minutesGranted: Int
    var isActive: Bool
    var sourceChallengeID: UUID?

    init(
        id: UUID = UUID(),
        startDate: Date = .now,
        expirationDate: Date,
        minutesGranted: Int,
        isActive: Bool = true,
        sourceChallengeID: UUID? = nil
    ) {
        self.id = id
        self.startDate = startDate
        self.expirationDate = expirationDate
        self.minutesGranted = minutesGranted
        self.isActive = isActive
        self.sourceChallengeID = sourceChallengeID
    }
}
