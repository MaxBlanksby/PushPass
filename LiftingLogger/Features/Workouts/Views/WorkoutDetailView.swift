import SwiftUI

struct WorkoutDetailView: View {
    let workout: Workout

    private var orderedExercises: [WorkoutExercise] {
        workout.exercises.sorted { $0.orderIndex < $1.orderIndex }
    }

    var body: some View {
        List {
            Section("Summary") {
                LabeledContent("Started", value: workout.startDate.formatted(date: .abbreviated, time: .shortened))
                if let endDate = workout.endDate {
                    LabeledContent("Finished", value: endDate.formatted(date: .abbreviated, time: .shortened))
                }
                LabeledContent("Exercises", value: "\(workout.exercises.count)")
            }

            ForEach(orderedExercises) { workoutExercise in
                Section(workoutExercise.exerciseNameSnapshot) {
                    ForEach(workoutExercise.sets.sorted { $0.setNumber < $1.setNumber }) { set in
                        HStack {
                            Text("Set \(set.setNumber)")
                            Spacer()
                            Text("\(set.weight, format: .number.precision(.fractionLength(0...2))) x \(set.repetitions)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(workout.name)
    }
}
