import Foundation
import Observation

@Observable
final class AppEnvironment {
    var dashboard = DashboardState()
}

@Observable
final class DashboardState {
    var restrictionStatus: RestrictionStatus = .notConfigured
    var remainingBaseMinutes: Int = 0
    var earnedMinutesAvailable: Int = 0
    var pushUpsCompletedToday: Int = 0
    var workoutsCompletedThisWeek: Int = 0
    var dailyExerciseGoal: String = "Complete a workout"
    var recentWorkoutSummary: String = "No workouts logged yet"
    var isScreenTimeAuthorized = false
    var hasRestrictedSelection = false
}

enum RestrictionStatus: String, CaseIterable, Identifiable {
    case notConfigured = "Not configured"
    case appsAvailable = "Apps available"
    case appsShielded = "Apps shielded"
    case earnedSessionActive = "Earned session active"
    case authorizationUnavailable = "Authorization unavailable"
    case dailyEarningLimitReached = "Daily earning limit reached"

    var id: String { rawValue }
}
