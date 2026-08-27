import Foundation
import SwiftUI

enum AppConstants {
    static let appName = "PushPass"
    static let tagline = "Plan, log, and track your workouts."

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

enum AppAppearanceMode: String, CaseIterable, Identifiable {
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }

    var colorScheme: ColorScheme {
        switch self {
        case .light:
            .light
        case .dark:
            .dark
        }
    }
}
