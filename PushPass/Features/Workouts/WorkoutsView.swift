import SwiftData
import SwiftUI

struct WorkoutsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Workout.startDate, order: .reverse) private var workouts: [Workout]
    @State private var activeWorkout: Workout?
    @State private var isShowingWorkout = false

    private var completedWorkouts: [Workout] {
        workouts.filter(\.isCompleted)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        startWorkout()
                    } label: {
                        Label("Start Empty Workout", systemImage: "plus.circle.fill")
                    }
                }

                if let inProgress = workouts.first(where: { !$0.isCompleted }) {
                    Section("In Progress") {
                        Button {
                            activeWorkout = inProgress
                            isShowingWorkout = true
                        } label: {
                            WorkoutRow(workout: inProgress)
                        }
                    }
                }

                Section("History") {
                    if completedWorkouts.isEmpty {
                        ContentUnavailableView("No Workouts Yet", systemImage: "dumbbell")
                    } else {
                        ForEach(completedWorkouts) { workout in
                            NavigationLink {
                                WorkoutDetailView(workout: workout)
                            } label: {
                                WorkoutRow(workout: workout)
                            }
                        }
                        .onDelete(perform: deleteWorkouts)
                    }
                }
            }
            .navigationTitle("Workouts")
            .sheet(item: $activeWorkout) { workout in
                WorkoutSessionView(workout: workout)
            }
        }
    }

    private func startWorkout() {
        let workout = Workout(name: "Workout")
        modelContext.insert(workout)
        try? modelContext.save()
        activeWorkout = workout
        isShowingWorkout = true
    }

    private func deleteWorkouts(at offsets: IndexSet) {
        for offset in offsets {
            modelContext.delete(completedWorkouts[offset])
        }
        try? modelContext.save()
    }
}

private struct WorkoutRow: View {
    let workout: Workout

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(workout.name)
                .font(.headline)
            Text(workout.startDate, format: .dateTime.month().day().hour().minute())
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("\(workout.exercises.count) exercises")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    WorkoutsView()
        .modelContainer(for: [Workout.self, WorkoutExercise.self, LiftSet.self, Exercise.self], inMemory: true)
}
