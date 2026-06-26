import Foundation
import SwiftData

enum ExerciseLibrary {
    static let builtInExercises: [Exercise] = [
        Exercise(name: "Push-up", muscleGroup: .chest, equipment: .bodyweight, instructions: "Keep a straight body line and lower under control."),
        Exercise(name: "Bench Press", muscleGroup: .chest, equipment: .barbell),
        Exercise(name: "Dumbbell Row", muscleGroup: .back, equipment: .dumbbell),
        Exercise(name: "Overhead Press", muscleGroup: .shoulders, equipment: .barbell),
        Exercise(name: "Lat Pulldown", muscleGroup: .back, equipment: .cable),
        Exercise(name: "Squat", muscleGroup: .quadriceps, equipment: .barbell),
        Exercise(name: "Romanian Deadlift", muscleGroup: .hamstrings, equipment: .barbell),
        Exercise(name: "Leg Press", muscleGroup: .quadriceps, equipment: .machine),
        Exercise(name: "Biceps Curl", muscleGroup: .biceps, equipment: .dumbbell),
        Exercise(name: "Triceps Pushdown", muscleGroup: .triceps, equipment: .cable),
        Exercise(name: "Plank", muscleGroup: .core, equipment: .bodyweight)
    ]

    @MainActor
    static func seedIfNeeded(in context: ModelContext) {
        var descriptor = FetchDescriptor<Exercise>()
        descriptor.fetchLimit = 1

        let existing = (try? context.fetch(descriptor)) ?? []
        guard existing.isEmpty else { return }

        for exercise in builtInExercises {
            context.insert(exercise)
        }

        if ((try? context.fetch(FetchDescriptor<UserPreferences>()))?.isEmpty == true) {
            context.insert(UserPreferences())
        }

        try? context.save()
    }
}
