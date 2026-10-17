import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(AppEnvironment.self) private var environment
    @Query(sort: \Workout.startDate, order: .reverse) private var workouts: [Workout]
    @Query(sort: \DailyRewardRecord.date, order: .reverse) private var rewardRecords: [DailyRewardRecord]
    @Query(sort: \EarnedAccessSession.expirationDate, order: .reverse) private var sessions: [EarnedAccessSession]
    @State private var isShowingSettings = false

    private var currentDateText: String {
        Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day().year())
    }

    private var todayRecord: DailyRewardRecord? {
        rewardRecords.first { Calendar.current.isDateInToday($0.date) }
    }

    private var activeSession: EarnedAccessSession? {
        sessions.first { $0.isActive && $0.expirationDate > .now }
    }

    private var workoutsThisWeek: Int {
        let interval = Calendar.current.dateInterval(of: .weekOfYear, for: .now)
        return workouts.filter { workout in
            guard workout.isCompleted, let interval else { return false }
            return interval.contains(workout.startDate)
        }.count
    }

    private var recentWorkoutSummary: String {
        guard let workout = workouts.first(where: \.isCompleted) else {
            return "No workouts logged yet"
        }
        return "\(workout.name) · \(workout.exercises.count) exercises"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PushPassTheme.sectionSpacing) {
                    header
                    statusSection
                    warningSection
                    actionSection
                    recentWorkoutSection
                }
                .padding(PushPassTheme.screenPadding)
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(AppConstants.appName)
                .font(.largeTitle.bold())
            Text(AppConstants.tagline)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(currentDateText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusSection: some View {
        return VStack(alignment: .leading, spacing: PushPassTheme.cardSpacing) {
            Text(activeSession == nil ? environment.dashboard.restrictionStatus.rawValue : RestrictionStatus.earnedSessionActive.rawValue)
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.blue.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: PushPassTheme.cornerRadius))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: PushPassTheme.cardSpacing) {
                MetricTile(title: "Remaining app time", value: "\(environment.dashboard.remainingBaseMinutes) min", systemImage: "timer")
                MetricTile(title: "Earned time", value: "\(activeSession?.minutesGranted ?? 0) min", systemImage: "bolt")
                MetricTile(title: "Push-ups today", value: "\(todayRecord?.pushUpsCompleted ?? 0)", systemImage: "figure.core.training")
                MetricTile(title: "Workouts this week", value: "\(workoutsThisWeek)", systemImage: "calendar")
            }

            Text("Goal: \(environment.dashboard.dailyExerciseGoal)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var warningSection: some View {
        let dashboard = environment.dashboard

        if !dashboard.isScreenTimeAuthorized {
            WarningBanner(
                title: "Screen Time authorization missing",
                message: "Restrictions are disabled until authorization is granted. Workout tracking remains available.",
                systemImage: "exclamationmark.shield"
            )
        }

        if !dashboard.hasRestrictedSelection {
            WarningBanner(
                title: "No restricted apps selected",
                message: "Choose apps during the Screen Time setup phase before shielding can be applied.",
                systemImage: "app.badge"
            )
        }
    }

    private var actionSection: some View {
        VStack(spacing: 12) {
            NavigationLink {
                EarnView()
            } label: {
                Label("Earn More Time", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            NavigationLink {
                WorkoutsView()
            } label: {
                Label("Start Workout", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }

    private var recentWorkoutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Most Recent Workout")
                .font(.headline)

            Text(recentWorkoutSummary)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: PushPassTheme.cornerRadius))
        }
    }
}

#Preview {
    TodayView()
        .environment(AppEnvironment())
}
