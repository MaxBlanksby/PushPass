import Foundation
import SwiftData

enum WeightUnit: String, CaseIterable, Codable, Identifiable {
    case pounds = "lb"
    case kilograms = "kg"

    var id: String { rawValue }
}

enum MuscleGroup: String, CaseIterable, Codable, Identifiable {
    case chest = "Chest"
    case back = "Back"
    case shoulders = "Shoulders"
    case biceps = "Biceps"
    case triceps = "Triceps"
    case forearms = "Forearms"
    case quadriceps = "Quadriceps"
    case hamstrings = "Hamstrings"
    case glutes = "Glutes"
    case calves = "Calves"
    case core = "Core"
    case fullBody = "Full body"
    case cardio = "Cardio"
    case other = "Other"

    var id: String { rawValue }
}

enum Equipment: String, CaseIterable, Codable, Identifiable {
    case barbell = "Barbell"
    case dumbbell = "Dumbbell"
    case machine = "Machine"
    case cable = "Cable"
    case bodyweight = "Bodyweight"
    case resistanceBand = "Resistance band"
    case kettlebell = "Kettlebell"
    case other = "Other"

    var id: String { rawValue }
}

enum LiftSetType: String, CaseIterable, Codable, Identifiable {
    case warmup = "Warm-up"
    case working = "Working"
    case drop = "Drop"

    var id: String { rawValue }
}

@Model
final class UserPreferences {
    @Attribute(.unique) var id: UUID
    var weightUnitRawValue: String
    var defaultRestSeconds: Int
    var onboardingCompleted: Bool
    var baseDailyMinutes: Int
    var pushUpsPerChallenge: Int
    var minutesPerChallenge: Int
    var maximumEarnedMinutesPerDay: Int
    var progressiveOverloadEnabled: Bool
    var createdAt: Date
    var updatedAt: Date

    var weightUnit: WeightUnit {
        get { WeightUnit(rawValue: weightUnitRawValue) ?? .pounds }
        set { weightUnitRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        weightUnit: WeightUnit = .pounds,
        defaultRestSeconds: Int = 90,
        onboardingCompleted: Bool = false,
        baseDailyMinutes: Int = 30,
        pushUpsPerChallenge: Int = AppConstants.Rewards.defaultPushUpsPerChallenge,
        minutesPerChallenge: Int = AppConstants.Rewards.defaultMinutesPerChallenge,
        maximumEarnedMinutesPerDay: Int = AppConstants.Rewards.defaultMaximumEarnedMinutesPerDay,
        progressiveOverloadEnabled: Bool = true,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.weightUnitRawValue = weightUnit.rawValue
        self.defaultRestSeconds = defaultRestSeconds
        self.onboardingCompleted = onboardingCompleted
        self.baseDailyMinutes = baseDailyMinutes
        self.pushUpsPerChallenge = pushUpsPerChallenge
        self.minutesPerChallenge = minutesPerChallenge
        self.maximumEarnedMinutesPerDay = maximumEarnedMinutesPerDay
        self.progressiveOverloadEnabled = progressiveOverloadEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class Exercise {
    @Attribute(.unique) var id: UUID
    var name: String
    var muscleGroupRawValue: String
    var equipmentRawValue: String
    var instructions: String
    var isCustom: Bool
    var isArchived: Bool
    var createdAt: Date

    var muscleGroup: MuscleGroup {
        get { MuscleGroup(rawValue: muscleGroupRawValue) ?? .other }
        set { muscleGroupRawValue = newValue.rawValue }
    }

    var equipment: Equipment {
        get { Equipment(rawValue: equipmentRawValue) ?? .other }
        set { equipmentRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        name: String,
        muscleGroup: MuscleGroup,
        equipment: Equipment,
        instructions: String = "",
        isCustom: Bool = false,
        isArchived: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.muscleGroupRawValue = muscleGroup.rawValue
        self.equipmentRawValue = equipment.rawValue
        self.instructions = instructions
        self.isCustom = isCustom
        self.isArchived = isArchived
        self.createdAt = createdAt
    }
}

@Model
final class Workout {
    @Attribute(.unique) var id: UUID
    var name: String
    var startDate: Date
    var endDate: Date?
    var notes: String
    var isCompleted: Bool
    @Relationship(deleteRule: .cascade, inverse: \WorkoutExercise.workout) var exercises: [WorkoutExercise]

    var totalDuration: TimeInterval {
        (endDate ?? .now).timeIntervalSince(startDate)
    }

    init(
        id: UUID = UUID(),
        name: String,
        startDate: Date = .now,
        endDate: Date? = nil,
        notes: String = "",
        isCompleted: Bool = false,
        exercises: [WorkoutExercise] = []
    ) {
        self.id = id
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
        self.isCompleted = isCompleted
        self.exercises = exercises
    }
}

@Model
final class WorkoutExercise {
    @Attribute(.unique) var id: UUID
    var orderIndex: Int
    var exercise: Exercise?
    var exerciseNameSnapshot: String
    var notes: String
    var minimumRepTarget: Int
    var maximumRepTarget: Int
    var workout: Workout?
    @Relationship(deleteRule: .cascade, inverse: \LiftSet.workoutExercise) var sets: [LiftSet]

    init(
        id: UUID = UUID(),
        orderIndex: Int,
        exercise: Exercise?,
        exerciseNameSnapshot: String,
        notes: String = "",
        minimumRepTarget: Int = 8,
        maximumRepTarget: Int = 12,
        workout: Workout? = nil,
        sets: [LiftSet] = []
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.exercise = exercise
        self.exerciseNameSnapshot = exerciseNameSnapshot
        self.notes = notes
        self.minimumRepTarget = minimumRepTarget
        self.maximumRepTarget = maximumRepTarget
        self.workout = workout
        self.sets = sets
    }
}

@Model
final class LiftSet {
    @Attribute(.unique) var id: UUID
    var setNumber: Int
    var weight: Double
    var repetitions: Int
    var setTypeRawValue: String
    var isCompleted: Bool
    var completedAt: Date?
    var workoutExercise: WorkoutExercise?

    var setType: LiftSetType {
        get { LiftSetType(rawValue: setTypeRawValue) ?? .working }
        set { setTypeRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        setNumber: Int,
        weight: Double = 0,
        repetitions: Int = 0,
        setType: LiftSetType = .working,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        workoutExercise: WorkoutExercise? = nil
    ) {
        self.id = id
        self.setNumber = setNumber
        self.weight = weight
        self.repetitions = repetitions
        self.setTypeRawValue = setType.rawValue
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.workoutExercise = workoutExercise
    }
}
