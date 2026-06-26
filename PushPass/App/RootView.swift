import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TabView {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "sun.max")
                }

            EarnView()
                .tabItem {
                    Label("Earn", systemImage: "figure.strengthtraining.traditional")
                }

            WorkoutsView()
                .tabItem {
                    Label("Workouts", systemImage: "dumbbell")
                }

            ProgressView()
                .tabItem {
                    Label("Progress", systemImage: "chart.xyaxis.line")
                }
        }
        .task {
            ExerciseLibrary.seedIfNeeded(in: modelContext)
        }
    }
}

#Preview {
    RootView()
        .environment(AppEnvironment())
}
