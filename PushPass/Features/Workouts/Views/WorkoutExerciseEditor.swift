import SwiftData
import SwiftUI

struct WorkoutExerciseEditor: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var workoutExercise: WorkoutExercise
    let topReportedSet: ReportedLiftSet?
    let onShowExerciseInfo: (Exercise) -> Void

    private var orderedSets: [LiftSet] {
        workoutExercise.sets.sorted { $0.setNumber < $1.setNumber }
    }

    private var completedSetCount: Int {
        workoutExercise.sets.filter(\.isCompleted).count
    }

    var body: some View {
        Section {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(workoutExercise.exerciseNameSnapshot)
                        .font(.headline)

                    Text("\(completedSetCount) of \(workoutExercise.sets.count) sets done")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    if let topReportedSet {
                        Text("Top set: \(topReportedSet.weight.formatted(.number.precision(.fractionLength(0...2)))) x \(topReportedSet.repetitions) on \(topReportedSet.completedAt.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if workoutExercise.exercise != nil {
                    Button {
                        if let exercise = workoutExercise.exercise {
                            onShowExerciseInfo(exercise)
                        }
                    } label: {
                        Image(systemName: "info.circle")
                            .imageScale(.large)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Show \(workoutExercise.exerciseNameSnapshot) information")
                }
            }

            ForEach(orderedSets) { set in
                LiftSetEditor(set: set)
            }
            .onDelete(perform: deleteSets)

            Button {
                addSet()
            } label: {
                Label("Add Set", systemImage: "plus.circle")
            }

            TextField("Exercise notes", text: $workoutExercise.notes, axis: .vertical)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func addSet() {
        let previous = orderedSets.last
        let set = LiftSet(
            setNumber: workoutExercise.sets.count + 1,
            weight: previous?.weight ?? 0,
            repetitions: previous?.repetitions ?? 0,
            workoutExercise: workoutExercise
        )
        workoutExercise.sets.append(set)
        modelContext.insert(set)
        try? modelContext.save()
    }

    private func deleteSets(at offsets: IndexSet) {
        for offset in offsets {
            modelContext.delete(orderedSets[offset])
        }
        try? modelContext.save()
    }
}

struct ReportedLiftSet {
    let weight: Double
    let repetitions: Int
    let completedAt: Date

    var estimatedOneRepMax: Double {
        weight * (1 + Double(repetitions) / 30)
    }
}

private struct LiftSetEditor: View {
    @Bindable var set: LiftSet

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text("\(set.setNumber)")
                .font(.headline)
                .frame(width: 28, height: 28)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: PushPassTheme.cornerRadius))

            VStack(alignment: .leading, spacing: 4) {
                Text("Weight")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField("0", value: $set.weight, format: .number.precision(.fractionLength(0...2)))
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Reps")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField("0", value: $set.repetitions, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
            }

            Button {
                set.isCompleted.toggle()
                set.completedAt = set.isCompleted ? .now : nil
            } label: {
                Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                    .imageScale(.large)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(set.isCompleted ? "Set complete" : "Set incomplete")
        }
    }
}
