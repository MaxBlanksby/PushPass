//
//  PushPassApp.swift
//  PushPass
//
//  Created by Max Blanksby on 6/26/26.
//

import SwiftUI
import SwiftData

@main
struct PushPassApp: App {
    @State private var environment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
        }
        .modelContainer(for: [
            UserPreferences.self,
            Exercise.self,
            WorkoutTemplate.self,
            WorkoutTemplateExercise.self,
            Workout.self,
            WorkoutExercise.self,
            LiftSet.self,
            PushUpChallenge.self,
            DailyRewardRecord.self,
            EarnedAccessSession.self
        ])
    }
}
