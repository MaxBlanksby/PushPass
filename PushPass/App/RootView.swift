import SwiftUI
import SwiftData

#if canImport(FamilyControls)
import FamilyControls
#endif

struct RootView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \EarnedAccessSession.expirationDate, order: .reverse) private var sessions: [EarnedAccessSession]
    @State private var permissionErrorMessage: String?

    #if canImport(FamilyControls)
    @State private var restrictedSelection = ScreenTimeSetupService.storedSelection
    @State private var isShowingActivityPicker = false
    #endif

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
            permissionErrorMessage = await ScreenTimeSetupService.requestAuthorizationIfNeeded(for: environment.dashboard)
            syncRestrictions()

            #if canImport(FamilyControls)
            if environment.dashboard.isScreenTimeAuthorized && !environment.dashboard.hasRestrictedSelection {
                isShowingActivityPicker = true
            }
            #endif
        }
        .task {
            await refreshRestrictionsLoop()
        }
        #if canImport(FamilyControls)
        .sheet(isPresented: $isShowingActivityPicker) {
            NavigationStack {
                FamilyActivityPicker(selection: $restrictedSelection)
                    .navigationTitle("Choose Apps")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                isShowingActivityPicker = false
                            }
                        }
                    }
            }
        }
        .onChange(of: restrictedSelection) { _, newSelection in
            ScreenTimeSetupService.store(selection: newSelection, dashboard: environment.dashboard)
            syncRestrictions()
        }
        #endif
        .alert("Screen Time Setup Needed", isPresented: Binding(
            get: { permissionErrorMessage != nil },
            set: { if !$0 { permissionErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(permissionErrorMessage ?? "Open Settings to finish Screen Time setup.")
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
