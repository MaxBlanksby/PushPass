import SwiftData
import SwiftUI
internal import Combine

struct WorkoutSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Bindable var workout: Workout
    @State private var isAddingExercise = false
    @State private var elapsedSeconds = 0

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var orderedExercises: [WorkoutExercise] {
        workout.exercises.sorted { $0.orderIndex < $1.orderIndex }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Workout name", text: $workout.name)
                    Text("Elapsed: \(Duration.seconds(elapsedSeconds).formatted(.time(pattern: .minuteSecond)))")
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button {
                        isAddingExercise = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus")
                    }
                }

                ForEach(orderedExercises) { workoutExercise in
                    WorkoutExerciseEditor(workoutExercise: workoutExercise)
                }
                .onDelete(perform: deleteExercises)
            }
            .navigationTitle("Active Workout")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard", role: .destructive) {
                        modelContext.delete(workout)
                        try? modelContext.save()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Finish") {
                        workout.isCompleted = true
                        workout.endDate = .now
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(workout.exercises.isEmpty)
                }
            }
            .sheet(isPresented: $isAddingExercise) {
                ExercisePickerView { exercise in
                    addExercise(exercise)
                    isAddingExercise = false
                }
            }
            .onReceive(timer) { _ in
                elapsedSeconds = Int(Date.now.timeIntervalSince(workout.startDate))
            }
        }
    }

    private func addExercise(_ exercise: Exercise) {
        let workoutExercise = WorkoutExercise(
            orderIndex: workout.exercises.count,
            exercise: exercise,
            exerciseNameSnapshot: exercise.name,
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
}
