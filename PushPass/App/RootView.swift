import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \EarnedAccessSession.expirationDate, order: .reverse) private var sessions: [EarnedAccessSession]

    var body: some View {
        TabView {
            WorkoutsView()
                .tabItem {
                    Label("Workouts", systemImage: "dumbbell")
                }

            ProgressView()
                .tabItem {
                    Label("Progress", systemImage: "chart.xyaxis.line")
                }

            EarnView()
                .tabItem {
                    Label("Earn", systemImage: "figure.strengthtraining.traditional")
                }
        }
        .task {
            ExerciseLibrary.seedIfNeeded(in: modelContext)
            syncRestrictions()
        }
        .task {
            await refreshRestrictionsLoop()
        }
    }

    private var activeAccessExpirationDate: Date? {
        sessions.first { $0.isActive && $0.expirationDate > .now }?.expirationDate
    }

    private func syncRestrictions() {
        RewardService.expireFinishedSessions(context: modelContext)
        ScreenTimeSetupService.syncRestrictions(
            dashboard: environment.dashboard,
            accessExpirationDate: activeAccessExpirationDate
        )
    }

    private func refreshRestrictionsLoop() async {
        while !Task.isCancelled {
            syncRestrictions()

            do {
                try await Task.sleep(for: .seconds(15))
            } catch {
                return
            }
        }
    }
}

#Preview {
    RootView()
        .environment(AppEnvironment())
}
