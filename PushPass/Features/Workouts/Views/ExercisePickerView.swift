import SwiftData
import SwiftUI

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var searchText = ""
    @State private var customName = ""
    @State private var selectedMuscleGroup: MuscleGroup = .other
    @State private var selectedEquipment: Equipment = .other
    @State private var exercisePendingDeletion: Exercise?

    let onSelect: (Exercise) -> Void

    private var filteredExercises: [Exercise] {
        exercises
            .filter { !$0.isArchived }
            .filter { ExerciseLibrary.matches($0, searchText: searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Library") {
                    ForEach(filteredExercises) { exercise in
                        HStack {
                            Button {
                                onSelect(exercise)
                            } label: {
                                ExerciseSummaryRow(exercise: exercise)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)

                            if exercise.isCustom {
                                Button {
                                    exercisePendingDeletion = exercise
                                } label: {
                                    Image(systemName: "trash.fill")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Delete \(exercise.name)")
                            }
                        }
                    }
                }

                Section("Create Custom Exercise") {
                    TextField("Exercise name", text: $customName)
                    Picker("Muscle group", selection: $selectedMuscleGroup) {
                        ForEach(MuscleGroup.allCases) { group in
                            Text(group.rawValue).tag(group)
                        }
                    }
                    Picker("Equipment", selection: $selectedEquipment) {
                        ForEach(Equipment.allCases) { equipment in
                            Text(equipment.rawValue).tag(equipment)
                        }
                    }
                    Button {
                        createExercise()
                    } label: {
                        Label("Create and Add", systemImage: "plus")
                    }
                    .disabled(customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .searchable(text: $searchText)
            .navigationTitle("Add Exercise")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                "Delete custom exercise?",
                isPresented: Binding(
                    get: { exercisePendingDeletion != nil },
                    set: { if !$0 { exercisePendingDeletion = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let exercise = exercisePendingDeletion {
                    Button("Delete \(exercise.name)", role: .destructive) {
                        deleteCustomExercise(exercise)
                        exercisePendingDeletion = nil
                    }
                }

                Button("Cancel", role: .cancel) { }
            } message: {
                if let exercise = exercisePendingDeletion {
                    Text("This removes \(exercise.name) from your exercise library.")
                }
            }
        }
    }

    private func createExercise() {
        let trimmedName = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let exercise = Exercise(
            name: trimmedName,
            muscleGroup: selectedMuscleGroup,
            equipment: selectedEquipment,
            isCustom: true
        )
        modelContext.insert(exercise)
        try? modelContext.save()
        onSelect(exercise)
    }

    private func deleteCustomExercise(_ exercise: Exercise) {
        guard exercise.isCustom else { return }

        modelContext.delete(exercise)
        try? modelContext.save()
    }
}
