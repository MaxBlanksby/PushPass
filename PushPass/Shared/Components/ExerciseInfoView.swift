import SwiftUI

struct ExerciseSummaryRow: View {
    let exercise: Exercise

    private var details: ExerciseDetails? {
        ExerciseLibrary.details(for: exercise)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(exercise.name)
                .font(.headline)

            if let details {
                Text("\(details.primaryMuscles) · \(details.equipment)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(exercise.muscleGroup.rawValue) · \(exercise.equipment.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct ExerciseInfoView: View {
    let exercise: Exercise

    private var details: ExerciseDetails? {
        ExerciseLibrary.details(for: exercise)
    }

    var body: some View {
        if let details {
            Section("Exercise Info") {
                LabeledContent("Category", value: details.category)
                LabeledContent("Primary", value: details.primaryMuscles)

                if !details.secondaryMuscles.isEmpty {
                    LabeledContent("Secondary", value: details.secondaryMuscles)
                }

                LabeledContent("Equipment", value: details.equipment)

                if !details.exerciseType.isEmpty {
                    LabeledContent("Type", value: details.exerciseType)
                }
            }

            if !details.setup.isEmpty {
                Section("Setup / How to Perform") {
                    Text(details.setup)
                }
            }

            if !details.formCues.isEmpty {
                Section("Form Cues") {
                    Text(details.formCues)
                }
            }
        } else {
            Section("Exercise Info") {
                LabeledContent("Category", value: exercise.muscleGroup.rawValue)
                LabeledContent("Equipment", value: exercise.equipment.rawValue)
            }
        }
    }
}

struct ExerciseInfoSheetView: View {
    @Environment(\.dismiss) private var dismiss
    let exercise: Exercise

    var body: some View {
        NavigationStack {
            List {
                ExerciseInfoView(exercise: exercise)
            }
            .navigationTitle(exercise.name)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
