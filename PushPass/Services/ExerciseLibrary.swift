import Foundation
import SwiftData

enum ExerciseLibrary {
    static var builtInExercises: [Exercise] {
        exerciseSeeds.map { seed in
            Exercise(
                name: seed.name,
                muscleGroup: seed.muscleGroup,
                equipment: seed.equipment,
                instructions: seed.instructions
            )
        }
    }

    @MainActor
    static func seedIfNeeded(in context: ModelContext) {
        let existingExercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        var existingNames = Set(existingExercises.map { normalizedName($0.name) })

        for exercise in builtInExercises {
            let normalized = normalizedName(exercise.name)
            guard !existingNames.contains(normalized) else { continue }

            context.insert(exercise)
            existingNames.insert(normalized)
        }

        if ((try? context.fetch(FetchDescriptor<UserPreferences>()))?.isEmpty == true) {
            context.insert(UserPreferences())
        }

        try? context.save()
    }

    private static var exerciseSeeds: [ExerciseSeed] {
        guard let url = Bundle.main.url(forResource: "PushPass_Exercise_Bank", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return fallbackExerciseSeeds
        }

        return parseExerciseBank(text)
    }

    private static let fallbackExerciseSeeds: [ExerciseSeed] = [
        ExerciseSeed(name: "Push-Up", muscleGroup: .chest, equipment: .bodyweight, instructions: "Keep a straight body line and lower under control."),
        ExerciseSeed(name: "Barbell Bench Press", muscleGroup: .chest, equipment: .barbell),
        ExerciseSeed(name: "Dumbbell Row", muscleGroup: .back, equipment: .dumbbell),
        ExerciseSeed(name: "Barbell Overhead Press", muscleGroup: .shoulders, equipment: .barbell),
        ExerciseSeed(name: "Lat Pulldown", muscleGroup: .back, equipment: .cable),
        ExerciseSeed(name: "Back Squat", muscleGroup: .quadriceps, equipment: .barbell),
        ExerciseSeed(name: "Romanian Deadlift", muscleGroup: .hamstrings, equipment: .barbell),
        ExerciseSeed(name: "Leg Press", muscleGroup: .quadriceps, equipment: .machine),
        ExerciseSeed(name: "Barbell Curl", muscleGroup: .biceps, equipment: .barbell),
        ExerciseSeed(name: "Triceps Pushdown", muscleGroup: .triceps, equipment: .cable),
        ExerciseSeed(name: "Plank", muscleGroup: .core, equipment: .bodyweight)
    ]

    private static let sectionMuscleGroups: [String: MuscleGroup] = [
        "Chest": .chest,
        "Back": .back,
        "Shoulders": .shoulders,
        "Biceps": .biceps,
        "Triceps": .triceps,
        "Forearms and Grip": .forearms,
        "Quadriceps": .quadriceps,
        "Hamstrings": .hamstrings,
        "Glutes": .glutes,
        "Calves": .calves,
        "Core": .core,
        "Full Body and Functional": .fullBody,
        "Cardio": .cardio,
        "Olympic Lifting": .fullBody,
        "Powerlifting-Specific": .fullBody,
        "Calisthenics": .fullBody,
        "Mobility and Recovery": .other,
        "Rehabilitation and Stability": .other
    ]

    private static func parseExerciseBank(_ text: String) -> [ExerciseSeed] {
        var currentMuscleGroup: MuscleGroup?
        var seenNames = Set<String>()
        var seeds: [ExerciseSeed] = []

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, line != "PushPass Exercise Bank" else { continue }

            if let muscleGroup = sectionMuscleGroups[line] {
                currentMuscleGroup = muscleGroup
                continue
            }

            guard let currentMuscleGroup else { continue }

            let normalized = normalizedName(line)
            guard !seenNames.contains(normalized) else { continue }

            seeds.append(ExerciseSeed(name: line, muscleGroup: currentMuscleGroup, equipment: inferredEquipment(for: line)))
            seenNames.insert(normalized)
        }

        return seeds.isEmpty ? fallbackExerciseSeeds : seeds
    }

    private static func normalizedName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func inferredEquipment(for exerciseName: String) -> Equipment {
        let name = exerciseName.lowercased()

        if name.contains("treadmill") ||
            name.contains("running") ||
            name.contains("walking") ||
            name.contains("jogging") ||
            name.contains("sprinting") ||
            name.contains("cycling") ||
            name.contains("bike") ||
            name.contains("elliptical") ||
            name.contains("swimming") ||
            name.contains("hiking") ||
            name.contains("dancing") ||
            name.contains("shuttle") ||
            name.contains("agility") {
            return .other
        }

        if name.contains("resistance band") || name.contains("banded") || name.contains("band ") {
            return .resistanceBand
        }

        if name.contains("cable") || name.contains("rope") || name.contains("lat pulldown") || name.contains("pushdown") {
            return .cable
        }

        if name.contains("machine") ||
            name.contains("smith") ||
            name.contains("pec deck") ||
            name.contains("leg press") ||
            name.contains("hack squat") ||
            name.contains("pendulum") ||
            name.contains("belt squat") ||
            name.contains("stair climber") ||
            name.contains("ski erg") ||
            name.contains("rowing machine") ||
            name.contains("air bike") ||
            name.contains("assault bike") {
            return .machine
        }

        if name.contains("dumbbell") {
            return .dumbbell
        }

        if name.contains("kettlebell") {
            return .kettlebell
        }

        if name.contains("barbell") ||
            name.contains("ez-bar") ||
            name.contains("landmine") ||
            name.contains("plate") ||
            name.contains("bench press") ||
            name.contains("deadlift") ||
            name.contains("squat") ||
            name.contains("good morning") {
            return .barbell
        }

        if name.contains("push-up") ||
            name.contains("pull-up") ||
            name.contains("chin-up") ||
            name.contains("dip") ||
            name.contains("plank") ||
            name.contains("crunch") ||
            name.contains("sit-up") ||
            name.contains("lunge") ||
            name.contains("step-up") ||
            name.contains("carry") ||
            name.contains("hold") ||
            name.contains("stretch") ||
            name.contains("pose") ||
            name.contains("crawl") ||
            name.contains("jump") ||
            name.contains("burpee") {
            return .bodyweight
        }

        return .other
    }
}

private struct ExerciseSeed {
    let name: String
    let muscleGroup: MuscleGroup
    let equipment: Equipment
    let instructions: String

    init(name: String, muscleGroup: MuscleGroup, equipment: Equipment, instructions: String = "") {
        self.name = name
        self.muscleGroup = muscleGroup
        self.equipment = equipment
        self.instructions = instructions
    }
}
