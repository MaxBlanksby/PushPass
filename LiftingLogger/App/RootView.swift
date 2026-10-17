import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("appearanceMode") private var appearanceModeRawValue = AppAppearanceMode.light.rawValue

    private var appearanceMode: AppAppearanceMode {
        AppAppearanceMode(rawValue: appearanceModeRawValue) ?? .light
    }

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

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .preferredColorScheme(appearanceMode.colorScheme)
        .task {
            ExerciseLibrary.seedIfNeeded(in: modelContext)
            try? modelContext.save()
        }
    }
}

#Preview {
    RootView()
        .environment(AppEnvironment())
}
