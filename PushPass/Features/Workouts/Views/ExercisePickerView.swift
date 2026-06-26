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

    let onSelect: (Exercise) -> Void

    private var filteredExercises: [Exercise] {
        exercises
            .filter { !$0.isArchived }
            .filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Library") {
                    ForEach(filteredExercises) { exercise in
                        Button {
                            onSelect(exercise)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(exercise.name)
                                Text("\(exercise.muscleGroup.rawValue) · \(exercise.equipment.rawValue)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
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
}
