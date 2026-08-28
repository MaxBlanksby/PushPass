import SwiftData
import SwiftUI
internal import Combine

#if canImport(UIKit)
import UIKit
#endif

struct WorkoutSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query(sort: \Workout.startDate, order: .reverse) private var workouts: [Workout]
    @Query private var preferences: [UserPreferences]
    @Bindable var workout: Workout
    @State private var isAddingExercise = false
    @State private var exerciseBeingViewed: Exercise?
    @State private var elapsedSeconds = 0
    @State private var currentDate = Date.now
    @State private var restTimerEndDatesBySetID: [UUID: Date] = [:]
    @FocusState private var focusedInput: WorkoutInputField?

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var orderedExercises: [WorkoutExercise] {
        workout.exercises.sorted { $0.orderIndex < $1.orderIndex }
    }

    private var completedWorkouts: [Workout] {
        workouts.filter(\.isCompleted)
    }

    private var prefs: UserPreferences {
        preferences.first ?? UserPreferences()
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Workout name", text: $workout.name)
                        .submitLabel(.done)
                        .focused($focusedInput, equals: .workoutName)
                        .onSubmit {
                            dismissKeyboard()
                        }
                    Text("Elapsed: \(Duration.seconds(elapsedSeconds).formatted(.time(pattern: .minuteSecond)))")
                        .foregroundStyle(.secondary)
                        .onTapGesture {
                            dismissKeyboard()
                        }
                }

                Section {
                    Button {
                        dismissKeyboard()
                        isAddingExercise = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus")
                    }
                }

                ForEach(orderedExercises) { workoutExercise in
                    WorkoutExerciseEditor(
                        workoutExercise: workoutExercise,
                        topReportedSet: topReportedSet(for: workoutExercise),
                        defaultRestSeconds: prefs.defaultRestSeconds,
                        restRemainingSecondsForSet: { set in
                            restRemainingSeconds(for: set)
                        },
                        isRestTimerFinishedForSet: { set in
                            isRestTimerFinished(for: set)
                        },
                        upperRepTarget: max(workoutExercise.maximumRepTarget, prefs.preferredMaximumRepTarget),
                        focusedInput: $focusedInput,
                        onShowExerciseInfo: { exercise in
                            dismissKeyboard()
                            exerciseBeingViewed = exercise
                        },
                        onStartRestTimer: { set in
                            dismissKeyboard()
                            startRestTimer(for: set)
                        }
                    )
                }
                .onDelete(perform: deleteExercises)
            }
            .navigationTitle("Active Workout")
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard", role: .destructive) {
                        dismissKeyboard()
                        modelContext.delete(workout)
                        try? modelContext.save()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Finish") {
                        dismissKeyboard()
                        workout.isCompleted = true
                        workout.endDate = .now
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(workout.exercises.isEmpty)
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()

                    Button("Done") {
                        dismissKeyboard()
                    }
                    .font(.headline)
                }
            }
            .sheet(isPresented: $isAddingExercise) {
                ExercisePickerView { exercise in
                    addExercise(exercise)
                    isAddingExercise = false
                }
            }
            .sheet(item: $exerciseBeingViewed) { exercise in
                NavigationStack {
                    ExerciseProgressView(exercise: exercise, workouts: completedWorkouts)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") {
                                    exerciseBeingViewed = nil
                                }
                            }
                        }
                }
            }
            .onReceive(timer) { _ in
                currentDate = .now
                elapsedSeconds = Int(currentDate.timeIntervalSince(workout.startDate))
            }
        }
    }

    private func restRemainingSeconds(for set: LiftSet) -> Int {
        guard let endDate = restTimerEndDatesBySetID[set.id] else { return 0 }
        return max(0, Int(ceil(endDate.timeIntervalSince(currentDate))))
    }

    private func isRestTimerFinished(for set: LiftSet) -> Bool {
        guard let endDate = restTimerEndDatesBySetID[set.id] else { return false }
        return endDate <= currentDate
    }

    private func startRestTimer(for set: LiftSet) {
        currentDate = .now
        restTimerEndDatesBySetID[set.id] = currentDate.addingTimeInterval(TimeInterval(prefs.defaultRestSeconds))
    }

    private func dismissKeyboard() {
        focusedInput = nil

        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }

    private func addExercise(_ exercise: Exercise) {
        let workoutExercise = WorkoutExercise(
            orderIndex: workout.exercises.count,
            exercise: exercise,
            exerciseNameSnapshot: exercise.name,
            minimumRepTarget: prefs.preferredMinimumRepTarget,
            maximumRepTarget: prefs.preferredMaximumRepTarget,
            workout: workout
        )
        let set = LiftSet(setNumber: 1, workoutExercise: workoutExercise)
        workoutExercise.sets.append(set)
        workout.exercises.append(workoutExercise)
        modelContext.insert(workoutExercise)
        modelContext.insert(set)
        try? modelContext.save()
    }

    private func deleteExercises(at offsets: IndexSet) {
        for offset in offsets {
            modelContext.delete(orderedExercises[offset])
        }
        try? modelContext.save()
    }

    private func topReportedSet(for workoutExercise: WorkoutExercise) -> ReportedLiftSet? {
        let matchingCompletedSets = workouts
            .filter { $0.id != workout.id && $0.isCompleted }
            .flatMap { historicalWorkout in
                historicalWorkout.exercises
                    .filter { historicalExercise in
                        exercisesMatch(historicalExercise, workoutExercise)
                    }
                    .flatMap { historicalExercise in
                        historicalExercise.sets
                            .filter(\.isCompleted)
                            .compactMap { set -> ReportedLiftSet? in
                                guard let completedAt = set.completedAt ?? historicalWorkout.endDate else { return nil }
                                return ReportedLiftSet(
                                    weight: set.weight,
                                    repetitions: set.repetitions,
                                    completedAt: completedAt
                                )
                            }
                    }
            }

        return matchingCompletedSets.max { lhs, rhs in
            if lhs.estimatedOneRepMax != rhs.estimatedOneRepMax {
                return lhs.estimatedOneRepMax < rhs.estimatedOneRepMax
            }

            if lhs.weight != rhs.weight {
                return lhs.weight < rhs.weight
            }

            if lhs.repetitions != rhs.repetitions {
                return lhs.repetitions < rhs.repetitions
            }

            return lhs.completedAt < rhs.completedAt
        }
    }

    private func exercisesMatch(_ lhs: WorkoutExercise, _ rhs: WorkoutExercise) -> Bool {
        if let lhsExerciseID = lhs.exercise?.id, let rhsExerciseID = rhs.exercise?.id {
            return lhsExerciseID == rhsExerciseID
        }

        return lhs.exerciseNameSnapshot.localizedCaseInsensitiveCompare(rhs.exerciseNameSnapshot) == .orderedSame
    }
}
