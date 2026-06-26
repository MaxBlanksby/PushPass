import Foundation

enum AppConstants {
    static let appName = "PushPass"
    static let tagline = "Earn your screen time."

    enum Rewards {
        static let defaultPushUpsPerChallenge = 10
        static let defaultMinutesPerChallenge = 5
        static let defaultMaximumEarnedMinutesPerDay = 45
        static let defaultMinimumChallengeBreakMinutes = 5
    }

    enum ScreenTime {
        static let appGroupIdentifier = "group.PP.PushPass"
        static let managedSettingsStoreName = "PushPassRestrictions"
        static let deviceActivityName = "PushPassDailyActivity"
        static let dailyAllowanceEventName = "PushPassDailyAllowanceReached"
    }
}
