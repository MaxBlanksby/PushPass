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
        let seeds = exerciseSeeds
        let canonicalNames = Set(seeds.map { normalizedName($0.name) })
        var existingByName: [String: Exercise] = [:]
        for exercise in existingExercises {
            let normalized = normalizedName(exercise.name)
            if existingByName[normalized] == nil || existingByName[normalized]?.isCustom == true {
                existingByName[normalized] = exercise
            }
        }

        for seed in seeds {
            let normalized = normalizedName(seed.name)

            if let existing = existingByName[normalized], !existing.isCustom {
                existing.name = seed.name
                existing.muscleGroup = seed.muscleGroup
                existing.equipment = seed.equipment
                existing.instructions = seed.instructions
                existing.isArchived = false
            } else {
                let exercise = Exercise(
                    name: seed.name,
                    muscleGroup: seed.muscleGroup,
                    equipment: seed.equipment,
                    instructions: seed.instructions
                )
                context.insert(exercise)
                existingByName[normalized] = exercise
            }
        }

        for exercise in existingExercises where !exercise.isCustom {
            exercise.isArchived = !canonicalNames.contains(normalizedName(exercise.name))
        }

        if ((try? context.fetch(FetchDescriptor<UserPreferences>()))?.isEmpty == true) {
            context.insert(UserPreferences())
        }

        try? context.save()
    }

    private static var exerciseSeeds: [ExerciseSeed] {
        if let jsonSeeds = jsonExerciseSeeds {
            return jsonSeeds
        }

        guard let url = Bundle.main.url(forResource: "LiftingLogger_Exercise_Bank", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return fallbackExerciseSeeds
        }

        return parseExerciseBank(text)
    }

    private static var jsonExerciseSeeds: [ExerciseSeed]? {
        guard let url = Bundle.main.url(forResource: "LiftingLogger_Exercise_Library", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let library = try? JSONDecoder().decode(ExerciseLibraryDocument.self, from: data) else {
            return nil
        }

        var seenNames = Set<String>()
        let seeds = library.exercises.compactMap { entry -> ExerciseSeed? in
            let normalized = normalizedName(entry.name)
            guard !seenNames.contains(normalized) else { return nil }
            seenNames.insert(normalized)

            let details = ExerciseDetails(
                name: entry.name,
                category: entry.category,
                primaryMuscles: entry.primaryMuscles,
                secondaryMuscles: entry.secondaryMuscles,
                equipment: entry.equipment,
                exerciseType: entry.exerciseType,
                setup: entry.setup,
                formCues: entry.formCues
            )

            return ExerciseSeed(
                name: entry.name,
                muscleGroup: muscleGroup(for: entry.category),
                equipment: inferredEquipment(for: entry.equipment),
                instructions: encodedDetails(details)
            )
        }

        return seeds.isEmpty ? nil : seeds
    }

    static func details(for exercise: Exercise) -> ExerciseDetails? {
        if let data = exercise.instructions.data(using: .utf8),
           let details = try? JSONDecoder().decode(ExerciseDetails.self, from: data) {
            return details
        }

        guard !exercise.instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return ExerciseDetails(
            name: exercise.name,
            category: exercise.muscleGroup.rawValue,
            primaryMuscles: exercise.muscleGroup.rawValue,
            secondaryMuscles: "",
            equipment: exercise.equipment.rawValue,
            exerciseType: "",
            setup: "",
            formCues: exercise.instructions
        )
    }

    /// Filters exercises using advanced search algorithm
    /// Returns exercises sorted by relevance score
    static func searchExercises(_ exercises: [Exercise], searchText: String) -> [Exercise] {
        return ExerciseSearchEngine.search(exercises, query: searchText)
    }

    /// Legacy method for backward compatibility - now uses advanced search
    /// Returns true if exercise matches the search text
    static func matches(_ exercise: Exercise, searchText: String) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }

        // Use the advanced search engine and check if this exercise is in the results
        let results = ExerciseSearchEngine.search([exercise], query: query)
        return !results.isEmpty
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
        "Full Body": .fullBody,
        "Powerlifting": .fullBody,
        "Mobility": .other,
        "Rehab and Stability": .other,
        "Adductors": .other,
        "Neck": .other,
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

    private static func muscleGroup(for category: String) -> MuscleGroup {
        let normalizedCategory = category.replacingOccurrences(of: "&", with: "and")
        return sectionMuscleGroups[category] ?? sectionMuscleGroups[normalizedCategory] ?? .other
    }

    private static func encodedDetails(_ details: ExerciseDetails) -> String {
        guard let data = try? JSONEncoder().encode(details),
              let text = String(data: data, encoding: .utf8) else {
            return details.formCues
        }

        return text
    }

    private static func parseExerciseBank(_ text: String) -> [ExerciseSeed] {
        var currentMuscleGroup: MuscleGroup?
        var seenNames = Set<String>()
        var seeds: [ExerciseSeed] = []

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, line != "LiftingLogger Exercise Bank" else { continue }

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

        if name.contains("bands") || name == "band" || name.contains("resistance band") || name.contains("banded") || name.contains("band ") {
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

struct ExerciseDetails: Codable, Equatable {
    let name: String
    let category: String
    let primaryMuscles: String
    let secondaryMuscles: String
    let equipment: String
    let exerciseType: String
    let setup: String
    let formCues: String
}

private struct ExerciseLibraryDocument: Decodable {
    let exercises: [ExerciseLibraryEntry]

    init(from decoder: Decoder) throws {
        if let entries = try? decoder.singleValueContainer().decode([ExerciseLibraryEntry].self) {
            exercises = entries
        } else {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            exercises = try container.decode([ExerciseLibraryEntry].self, forKey: .exercises)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case exercises
    }
}

private struct ExerciseLibraryEntry: Decodable {
    let category: String
    let name: String
    let primaryMuscles: String
    let secondaryMuscles: String
    let equipment: String
    let exerciseType: String
    let setup: String
    let formCues: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        func text(_ key: CodingKeys, separator: String = ", ") throws -> String {
            if let values = try? container.decode([String].self, forKey: key) {
                return values.joined(separator: separator)
            }
            return try container.decode(String.self, forKey: key)
        }
        category = try text(.category)
        name = try text(.name)
        primaryMuscles = try text(.primaryMuscles)
        secondaryMuscles = try text(.secondaryMuscles)
        equipment = try text(.equipment)
        exerciseType = try text(.exerciseType)
        setup = try text(.setup)
        formCues = try text(.formCues, separator: "\n")
    }

    private enum CodingKeys: String, CodingKey {
        case category
        case name
        case primaryMuscles = "primary_muscles"
        case secondaryMuscles = "secondary_muscles"
        case equipment
        case exerciseType = "exercise_type"
        case setup
        case formCues = "form_cues"
    }
}
