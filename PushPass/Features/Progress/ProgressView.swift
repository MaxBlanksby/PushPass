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

                Section("List of All Exercises") {
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
    @Environment(\.modelContext) private var modelContext
    let exercise: Exercise
    let workouts: [Workout]
    @State private var selectedChartMode = ExerciseChartMode.volume
    @State private var isShowingSetHistory = false
    @State private var setBeingEdited: LiftSet?
    @State private var setPendingDeletion: LiftSet?

    private var completedSets: [CompletedExerciseSet] {
        workouts.flatMap { workout in
            workout.exercises.filter { $0.exercise?.id == exercise.id || $0.exerciseNameSnapshot == exercise.name }
                .flatMap(\.sets)
                .filter(\.isCompleted)
                .map { set in
                    CompletedExerciseSet(
                        liftSet: set,
                        completedAt: set.completedAt ?? workout.endDate ?? workout.startDate
                    )
                }
        }
        .sorted { $0.completedAt > $1.completedAt }
    }

    private var bestWeight: Double {
        completedSets.map(\.liftSet.weight).max() ?? 0
    }

    private var bestReps: Int {
        completedSets.map(\.liftSet.repetitions).max() ?? 0
    }

    private var estimatedOneRepMax: Double {
        completedSets.map { estimatedOneRepMaxValue(for: $0.liftSet) }.max() ?? 0
    }

    private var chartPoints: [ExerciseChartPoint] {
        completedSets.map { completedSet in
            ExerciseChartPoint(
                date: completedSet.completedAt,
                weight: completedSet.liftSet.weight,
                repetitions: completedSet.liftSet.repetitions
            )
        }
        .sorted { $0.date < $1.date }
    }

    private var recentCompletedSets: [CompletedExerciseSet] {
        Array(completedSets.prefix(3))
    }

    var body: some View {
        List {
            Section("Best") {
                LabeledContent("Best weight", value: bestWeight.formatted(.number.precision(.fractionLength(0...2))))
                LabeledContent("Best reps", value: "\(bestReps)")
                LabeledContent("Estimated 1RM", value: estimatedOneRepMax.formatted(.number.precision(.fractionLength(0...2))))
            }

            if !chartPoints.isEmpty {
                Section {
                    Picker("Trend", selection: $selectedChartMode) {
                        ForEach(ExerciseChartMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Chart(chartPoints) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value(selectedChartMode.axisLabel, selectedChartMode.value(for: point))
                        )
                        PointMark(
                            x: .value("Date", point.date),
                            y: .value(selectedChartMode.axisLabel, selectedChartMode.value(for: point))
                        )
                    }
                    .frame(height: 220)
                }
            }

            Section("Completed Sets") {
                if completedSets.isEmpty {
                    ContentUnavailableView("No Sets Logged", systemImage: "chart.xyaxis.line")
                } else {
                    ForEach(recentCompletedSets) { completedSet in
                        CompletedSetRow(completedSet: completedSet) {
                            setBeingEdited = completedSet.liftSet
                        } onDelete: {
                            setPendingDeletion = completedSet.liftSet
                        }
                    }

                    if completedSets.count > recentCompletedSets.count {
                        Button {
                            isShowingSetHistory = true
                        } label: {
                            Label("Show History", systemImage: "clock.arrow.circlepath")
                        }
                    }
                }
            }
        }
        .navigationTitle(exercise.name)
        .sheet(isPresented: $isShowingSetHistory) {
            NavigationStack {
                List {
                    ForEach(completedSets) { completedSet in
                        CompletedSetRow(completedSet: completedSet) {
                            setBeingEdited = completedSet.liftSet
                        } onDelete: {
                            setPendingDeletion = completedSet.liftSet
                        }
                    }
                }
                .navigationTitle("Set History")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            isShowingSetHistory = false
                        }
                    }
                }
            }
        }
        .sheet(item: $setBeingEdited) { set in
            EditLiftSetView(set: set)
        }
        .confirmationDialog(
            "Delete this set?",
            isPresented: Binding(
                get: { setPendingDeletion != nil },
                set: { if !$0 { setPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Set", role: .destructive) {
                if let setPendingDeletion {
                    delete(setPendingDeletion)
                }
                setPendingDeletion = nil
            }

            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This removes the set from your progress data.")
        }
    }

    private func delete(_ set: LiftSet) {
        modelContext.delete(set)
        try? modelContext.save()
    }
}

private enum ExerciseChartMode: String, CaseIterable, Identifiable {
    case volume = "Volume Trend"
    case weight = "Weight Trend"

    var id: Self { self }

    var axisLabel: String {
        switch self {
        case .volume:
            return "Volume"
        case .weight:
            return "Weight"
        }
    }

    func value(for point: ExerciseChartPoint) -> Double {
        switch self {
        case .volume:
            return point.volume
        case .weight:
            return point.weight
        }
    }
}

private struct CompletedExerciseSet: Identifiable {
    let liftSet: LiftSet
    let completedAt: Date

    var id: UUID {
        liftSet.id
    }
}

private struct CompletedSetRow: View {
    let completedSet: CompletedExerciseSet
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Set \(completedSet.liftSet.setNumber)")
                    .font(.headline)

                Text(completedSet.completedAt, format: .dateTime.month().day().year().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(completedSet.liftSet.weight.formatted(.number.precision(.fractionLength(0...2)))) x \(completedSet.liftSet.repetitions)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)

            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .imageScale(.large)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Edit set")

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .imageScale(.large)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Delete set")
        }
    }
}

private struct EditLiftSetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let set: LiftSet
    @State private var weight: Double
    @State private var repetitions: Int

    init(set: LiftSet) {
        self.set = set
        _weight = State(initialValue: set.weight)
        _repetitions = State(initialValue: set.repetitions)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Set") {
                    TextField("Weight", value: $weight, format: .number.precision(.fractionLength(0...2)))
                        .keyboardType(.decimalPad)
                    TextField("Reps", value: $repetitions, format: .number)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("Edit Set")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        set.weight = max(0, weight)
                        set.repetitions = max(0, repetitions)
                        if set.completedAt == nil {
                            set.completedAt = .now
                        }
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
        }
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

private func estimatedOneRepMaxValue(for set: LiftSet) -> Double {
    set.weight * (1 + Double(set.repetitions) / 30)
}

#Preview {
    ProgressView()
        .modelContainer(for: [Workout.self, WorkoutExercise.self, LiftSet.self, Exercise.self, DailyRewardRecord.self], inMemory: true)
}
