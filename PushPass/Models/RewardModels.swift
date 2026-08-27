import Foundation
import SwiftData

enum WalletTransactionType: String, Codable, CaseIterable, Identifiable {
    case pushupsEarned
    case timeRedeemed
    case refund
    case adjustment

    var id: String { rawValue }
}

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

@Model
final class TimeWallet {
    @Attribute(.unique) var id: UUID
    var availableSeconds: Int
    var lifetimeEarnedSeconds: Int
    var lifetimeSpentSeconds: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        availableSeconds: Int = 0,
        lifetimeEarnedSeconds: Int = 0,
        lifetimeSpentSeconds: Int = 0,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.availableSeconds = availableSeconds
        self.lifetimeEarnedSeconds = lifetimeEarnedSeconds
        self.lifetimeSpentSeconds = lifetimeSpentSeconds
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class WalletTransaction {
    @Attribute(.unique) var id: UUID
    var typeRawValue: String
    var seconds: Int
    var timestamp: Date
    var relatedPushupSessionID: UUID?
    var relatedRuleID: UUID?

    var type: WalletTransactionType {
        get { WalletTransactionType(rawValue: typeRawValue) ?? .adjustment }
        set { typeRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        type: WalletTransactionType,
        seconds: Int,
        timestamp: Date = .now,
        relatedPushupSessionID: UUID? = nil,
        relatedRuleID: UUID? = nil
    ) {
        self.id = id
        self.typeRawValue = type.rawValue
        self.seconds = seconds
        self.timestamp = timestamp
        self.relatedPushupSessionID = relatedPushupSessionID
        self.relatedRuleID = relatedRuleID
    }
}

@Model
final class PushupEconomySettings {
    @Attribute(.unique) var id: UUID
    var secondsPerPushup: Int
    var minimumRedeemSeconds: Int
    var maximumBankSeconds: Int?
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        secondsPerPushup: Int = 60,
        minimumRedeemSeconds: Int = 60,
        maximumBankSeconds: Int? = nil,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.secondsPerPushup = secondsPerPushup
        self.minimumRedeemSeconds = minimumRedeemSeconds
        self.maximumBankSeconds = maximumBankSeconds
        self.updatedAt = updatedAt
    }
}
