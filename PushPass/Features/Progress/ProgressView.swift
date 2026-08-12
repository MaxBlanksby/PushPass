import SwiftData
import SwiftUI
import Charts

struct ProgressView: View {
    @Query(sort: \Workout.startDate, order: .reverse) private var workouts: [Workout]
    @Query(sort: \DailyRewardRecord.date, order: .reverse) private var rewardRecords: [DailyRewardRecord]
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var selectedExercise: Exercise?
    @State private var searchText = ""

    private var completedWorkouts: [Workout] {
        workouts.filter(\.isCompleted)
    }

    private var visibleExercises: [Exercise] {
        exercises
            .filter { !$0.isArchived }
            .filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var recentExercises: [RecentExercise] {
        var recentsByKey: [String: RecentExercise] = [:]

        for workout in completedWorkouts {
            for workoutExercise in workout.exercises {
                let completedSets = workoutExercise.sets.filter(\.isCompleted)
                guard !completedSets.isEmpty else { continue }

                let exerciseName = workoutExercise.exercise?.name ?? workoutExercise.exerciseNameSnapshot
                let key = workoutExercise.exercise?.id.uuidString ?? exerciseName.lowercased()
                let latestSet = completedSets.max {
                    ($0.completedAt ?? workout.endDate ?? workout.startDate) < ($1.completedAt ?? workout.endDate ?? workout.startDate)
                }
                let lastPerformedAt = latestSet?.completedAt ?? workout.endDate ?? workout.startDate
                let totalVolume = completedSets.reduce(0) { $0 + ($1.weight * Double($1.repetitions)) }

                let recent = RecentExercise(
                    id: key,
                    exercise: workoutExercise.exercise,
                    exerciseName: exerciseName,
                    lastPerformedAt: lastPerformedAt,
                    completedSetCount: completedSets.count,
                    totalVolume: totalVolume,
                    lastWeight: latestSet?.weight ?? 0,
                    lastRepetitions: latestSet?.repetitions ?? 0
                )

                if let existing = recentsByKey[key] {
                    if recent.lastPerformedAt > existing.lastPerformedAt {
                        recentsByKey[key] = recent
                    }
                } else {
                    recentsByKey[key] = recent
                }
            }
        }

        return recentsByKey.values.sorted { $0.lastPerformedAt > $1.lastPerformedAt }
    }

    private var totalPushUps: Int {
        rewardRecords.map(\.pushUpsCompleted).reduce(0, +)
    }

    private var totalMinutesEarned: Int {
        rewardRecords.map(\.minutesEarned).reduce(0, +)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Summary") {
                    LabeledContent("Total workouts", value: "\(completedWorkouts.count)")
                    LabeledContent("Current streak", value: "\(currentWorkoutStreak) days")
                    LabeledContent("Total push-ups", value: "\(totalPushUps)")
                    LabeledContent("Total minutes earned", value: "\(totalMinutesEarned)")
                }

                Section("Recent Exercises") {
                    if recentExercises.isEmpty {
                        ContentUnavailableView("No Recent Exercises", systemImage: "clock.arrow.circlepath")
                    } else {
                        ForEach(recentExercises) { recentExercise in
                            if let exercise = recentExercise.exercise ?? exercises.first(where: { $0.name == recentExercise.exerciseName }) {
                                NavigationLink {
                                    ExerciseProgressView(exercise: exercise, workouts: completedWorkouts)
                                } label: {
                                    RecentExerciseRow(recentExercise: recentExercise)
                                }
                            } else {
                                RecentExerciseRow(recentExercise: recentExercise)
                            }
                        }
                    }
                }

                Section("Exercise History") {
                    if exercises.filter({ !$0.isArchived }).isEmpty {
                        ContentUnavailableView("No Exercise Data", systemImage: "chart.xyaxis.line")
                    } else if visibleExercises.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                    } else {
                        ForEach(visibleExercises) { exercise in
                            NavigationLink {
                                ExerciseProgressView(exercise: exercise, workouts: completedWorkouts)
                            } label: {
                                Text(exercise.name)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Progress")
        }
    }

    private var currentWorkoutStreak: Int {
        let workoutDays = Set(completedWorkouts.map { Calendar.current.startOfDay(for: $0.startDate) })
        var streak = 0
        var day = Calendar.current.startOfDay(for: .now)

        while workoutDays.contains(day) {
            streak += 1
            guard let previous = Calendar.current.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }

        return streak
    }
}

private struct RecentExercise: Identifiable {
    let id: String
    let exercise: Exercise?
    let exerciseName: String
    let lastPerformedAt: Date
    let completedSetCount: Int
    let totalVolume: Double
    let lastWeight: Double
    let lastRepetitions: Int
}

private struct RecentExerciseRow: View {
    let recentExercise: RecentExercise

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(recentExercise.exerciseName)
                .font(.headline)

            Text(recentExercise.lastPerformedAt, format: .dateTime.month().day().hour().minute())
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("\(recentExercise.completedSetCount) sets · last \(recentExercise.lastWeight.formatted(.number.precision(.fractionLength(0...2)))) x \(recentExercise.lastRepetitions) · volume \(recentExercise.totalVolume.formatted(.number.precision(.fractionLength(0...0))))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct ExerciseProgressView: View {
    let exercise: Exercise
    let workouts: [Workout]

    private var sets: [LiftSet] {
        workouts.flatMap { workout in
            workout.exercises.filter { $0.exercise?.id == exercise.id || $0.exerciseNameSnapshot == exercise.name }
                .flatMap(\.sets)
                .filter(\.isCompleted)
        }
    }

    private var bestWeight: Double {
        sets.map(\.weight).max() ?? 0
    }

    private var bestReps: Int {
        sets.map(\.repetitions).max() ?? 0
    }

    private var estimatedOneRepMax: Double {
        sets.map { $0.weight * (1 + Double($0.repetitions) / 30) }.max() ?? 0
    }

    private var chartPoints: [ExerciseChartPoint] {
        sets.compactMap { set in
            guard let completedAt = set.completedAt else { return nil }
            return ExerciseChartPoint(date: completedAt, weight: set.weight, repetitions: set.repetitions)
        }
        .sorted { $0.date < $1.date }
    }

    var body: some View {
        List {
            Section("Best") {
                LabeledContent("Best weight", value: bestWeight.formatted(.number.precision(.fractionLength(0...2))))
                LabeledContent("Best reps", value: "\(bestReps)")
                LabeledContent("Estimated 1RM", value: estimatedOneRepMax.formatted(.number.precision(.fractionLength(0...2))))
            }

            if !chartPoints.isEmpty {
                Section("Volume Trend") {
                    Chart(chartPoints) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Volume", point.volume)
                        )
                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("Volume", point.volume)
                        )
                    }
                    .frame(height: 220)
                }
            }

            Section("Completed Sets") {
                if sets.isEmpty {
                    ContentUnavailableView("No Sets Logged", systemImage: "chart.xyaxis.line")
                } else {
                    ForEach(Array(sets.enumerated()), id: \.offset) { _, set in
                        LabeledContent("Set \(set.setNumber)", value: "\(set.weight.formatted(.number.precision(.fractionLength(0...2)))) x \(set.repetitions)")
                    }
                }
            }
        }
        .navigationTitle(exercise.name)
    }
}

private struct ExerciseChartPoint: Identifiable {
    let id = UUID()
    let date: Date
    let weight: Double
    let repetitions: Int

    var volume: Double {
        weight * Double(repetitions)
    }
}

#Preview {
    ProgressView()
        .modelContainer(for: [Workout.self, WorkoutExercise.self, LiftSet.self, Exercise.self, DailyRewardRecord.self], inMemory: true)
}
