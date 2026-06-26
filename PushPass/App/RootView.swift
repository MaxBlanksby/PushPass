import SwiftUI

struct RootView: View {
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
    }
}

#Preview {
    RootView()
        .environment(AppEnvironment())
}
