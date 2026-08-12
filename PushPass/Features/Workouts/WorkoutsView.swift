import SwiftData
import SwiftUI

struct WorkoutsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query(sort: \WorkoutTemplate.updatedAt, order: .reverse) private var workoutTemplates: [WorkoutTemplate]
    @Query(sort: \Workout.startDate, order: .reverse) private var workouts: [Workout]
    @State private var activeWorkout: Workout?
    @State private var isBuildingCustomWorkout = false
    @State private var templateBeingEdited: WorkoutTemplate?
    @State private var isShowingWorkoutHistory = false

    private var completedWorkouts: [Workout] {
        workouts.filter(\.isCompleted)
    }

    private var recentCompletedWorkouts: [Workout] {
        Array(completedWorkouts.prefix(3))
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

                    Button {
                        isBuildingCustomWorkout = true
                    } label: {
                        Label("Create Custom Workout", systemImage: "list.bullet.clipboard")
                    }
                }

                if !workoutTemplates.isEmpty {
                    Section("Saved Custom Workouts") {
                        ForEach(workoutTemplates) { template in
                            HStack(spacing: 12) {
                                WorkoutTemplateRow(template: template)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Button {
                                    templateBeingEdited = template
                                } label: {
                                    Image(systemName: "pencil")
                                        .imageScale(.large)
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Edit \(template.name)")

                                Button {
                                    startWorkout(from: template)
                                } label: {
                                    Image(systemName: "play.fill")
                                        .imageScale(.large)
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Start \(template.name)")
                            }
                        }
                        .onDelete(perform: deleteTemplates)
                    }
                }

                if let inProgress = workouts.first(where: { !$0.isCompleted }) {
                    Section("In Progress") {
                        Button {
                            activeWorkout = inProgress
                        } label: {
                            WorkoutRow(workout: inProgress)
                        }
                    }
                }

                Section("History") {
                    if completedWorkouts.isEmpty {
                        ContentUnavailableView("No Workouts Yet", systemImage: "dumbbell")
                    } else {
                        ForEach(recentCompletedWorkouts) { workout in
                            NavigationLink {
                                WorkoutDetailView(workout: workout)
                            } label: {
                                WorkoutRow(workout: workout)
                            }
                        }
                        .onDelete(perform: deleteWorkouts)

                        if completedWorkouts.count > recentCompletedWorkouts.count {
                            Button {
                                isShowingWorkoutHistory = true
                            } label: {
                                Label("Show History", systemImage: "clock.arrow.circlepath")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Workouts")
            .navigationDestination(isPresented: $isShowingWorkoutHistory) {
                WorkoutHistoryView(workouts: completedWorkouts)
            }
            .sheet(item: $activeWorkout) { workout in
                WorkoutSessionView(workout: workout)
            }
            .sheet(isPresented: $isBuildingCustomWorkout) {
                CustomWorkoutBuilderView {
                    isBuildingCustomWorkout = false
                }
            }
            .sheet(item: $templateBeingEdited) { template in
                CustomWorkoutBuilderView(
                    template: template,
                    onSave: {
                        templateBeingEdited = nil
                    },
                    onDelete: {
                        templateBeingEdited = nil
                    }
                )
            }
        }
    }

    private func startWorkout() {
        let workout = Workout(name: "Workout")
        modelContext.insert(workout)
        try? modelContext.save()
        activeWorkout = workout
    }

    private func startWorkout(from template: WorkoutTemplate) {
        let workout = Workout(name: template.name)
        modelContext.insert(workout)

        let templateExercises = template.exercises.sorted { $0.orderIndex < $1.orderIndex }
        for (index, templateExercise) in templateExercises.enumerated() {
            let workoutExercise = WorkoutExercise(
                orderIndex: index,
                exercise: templateExercise.exercise,
                exerciseNameSnapshot: templateExercise.exerciseNameSnapshot,
                workout: workout
            )
            workout.exercises.append(workoutExercise)
            modelContext.insert(workoutExercise)
            let plannedSetCount = max(1, templateExercise.plannedSetCount)
            for setNumber in 1...plannedSetCount {
                let set = LiftSet(setNumber: setNumber, workoutExercise: workoutExercise)
                workoutExercise.sets.append(set)
                modelContext.insert(set)
            }
        }

        try? modelContext.save()
        activeWorkout = workout
    }

    private func deleteTemplates(at offsets: IndexSet) {
        for offset in offsets {
            modelContext.delete(workoutTemplates[offset])
        }
        try? modelContext.save()
    }

    private func deleteWorkouts(at offsets: IndexSet) {
        for offset in offsets {
            modelContext.delete(recentCompletedWorkouts[offset])
        }
        try? modelContext.save()
    }
}

private struct WorkoutHistoryView: View {
    let workouts: [Workout]

    var body: some View {
        List {
            ForEach(workouts) { workout in
                NavigationLink {
                    WorkoutDetailView(workout: workout)
                } label: {
                    WorkoutRow(workout: workout)
                }
            }
        }
        .navigationTitle("Workout History")
    }
}

private struct CustomWorkoutBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var workoutName = "Workout"
    @State private var selectedExerciseDrafts: [SelectedExerciseDraft] = []
    @State private var searchText = ""
    @State private var customExerciseName = ""
    @State private var newlyCreatedExercises: [Exercise] = []
    @State private var exercisePendingDeletion: Exercise?

    let template: WorkoutTemplate?
    let onSave: () -> Void
    let onDelete: (() -> Void)?

    init(
        template: WorkoutTemplate? = nil,
        onSave: @escaping () -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.template = template
        self.onSave = onSave
        self.onDelete = onDelete
        _workoutName = State(initialValue: template?.name ?? "Workout")
        _selectedExerciseDrafts = State(initialValue: template?.exercises
            .sorted { $0.orderIndex < $1.orderIndex }
            .compactMap { templateExercise in
                guard let exerciseID = templateExercise.exercise?.id else { return nil }
                return SelectedExerciseDraft(
                    exerciseID: exerciseID,
                    setCount: max(1, templateExercise.plannedSetCount)
                )
            } ?? [])
    }

    private var allExercises: [Exercise] {
        exercises + newlyCreatedExercises.filter { createdExercise in
            !exercises.contains { $0.id == createdExercise.id }
        }
    }

    private var availableExercises: [Exercise] {
        allExercises
            .filter { !$0.isArchived }
            .filter { ExerciseLibrary.matches($0, searchText: searchText) }
    }

    private var selectedExercises: [Exercise] {
        selectedExerciseDrafts.compactMap { draft in
            allExercises.first { $0.id == draft.exerciseID }
        }
    }

    private var trimmedWorkoutName: String {
        let trimmed = workoutName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Workout" : trimmed
    }

    private var trimmedCustomExerciseName: String {
        customExerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Workout name", text: $workoutName)
                }

                if !selectedExercises.isEmpty {
                    Section("Selected") {
                        ForEach(Array(selectedExerciseDrafts.enumerated()), id: \.element.id) { index, draft in
                            if let exercise = allExercises.first(where: { $0.id == draft.exerciseID }) {
                                SelectedExerciseRow(
                                    index: index,
                                    exercise: exercise,
                                    setCount: Binding(
                                        get: { selectedExerciseDrafts[index].setCount },
                                        set: { selectedExerciseDrafts[index].setCount = max(1, $0) }
                                    )
                                ) {
                                    toggleSelection(for: exercise)
                                }
                            } else {
                                Button("Remove unavailable exercise") {
                                    selectedExerciseDrafts.removeAll { $0.id == draft.id }
                                }
                            }
                        }
                    }
                }

                if template != nil {
                    Section {
                        Button("Delete Workout", role: .destructive) {
                            deleteTemplate()
                        }
                    }
                }

                Section("Create Custom Exercise") {
                    TextField("Exercise name", text: $customExerciseName)

                    Button {
                        createCustomExercise()
                    } label: {
                        Label("Create and Select", systemImage: "plus.circle")
                    }
                    .disabled(trimmedCustomExerciseName.isEmpty)
                }

                Section("Exercises") {
                    ForEach(availableExercises) { exercise in
                        HStack {
                            Button {
                                toggleSelection(for: exercise)
                            } label: {
                                ExerciseSummaryRow(exercise: exercise)

                                Spacer()

                                Image(systemName: isSelected(exercise) ? "checkmark.circle.fill" : "circle")
                                    .imageScale(.large)
                                    .foregroundStyle(isSelected(exercise) ? .blue : .secondary)
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
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle(template == nil ? "Custom Workout" : "Edit Workout")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveTemplate()
                    }
                    .disabled(selectedExerciseDrafts.isEmpty)
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
                    Text("This removes \(exercise.name) from your exercise library and from this workout draft.")
                }
            }
        }
    }

    private func toggleSelection(for exercise: Exercise) {
        if let index = selectedExerciseDrafts.firstIndex(where: { $0.exerciseID == exercise.id }) {
            selectedExerciseDrafts.remove(at: index)
        } else {
            selectedExerciseDrafts.append(SelectedExerciseDraft(exerciseID: exercise.id))
        }
    }

    private func isSelected(_ exercise: Exercise) -> Bool {
        selectedExerciseDrafts.contains { $0.exerciseID == exercise.id }
    }

    private func createCustomExercise() {
        let name = trimmedCustomExerciseName
        guard !name.isEmpty else { return }

        if let existing = allExercises.first(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
            if !isSelected(existing) {
                selectedExerciseDrafts.append(SelectedExerciseDraft(exerciseID: existing.id))
            }
            customExerciseName = ""
            return
        }

        let exercise = Exercise(name: name, muscleGroup: .other, equipment: .other, isCustom: true)
        modelContext.insert(exercise)
        try? modelContext.save()
        newlyCreatedExercises.append(exercise)
        selectedExerciseDrafts.append(SelectedExerciseDraft(exerciseID: exercise.id))
        customExerciseName = ""
    }

    private func saveTemplate() {
        let template = template ?? WorkoutTemplate(name: trimmedWorkoutName)
        template.name = trimmedWorkoutName
        template.updatedAt = .now

        if self.template == nil {
            modelContext.insert(template)
        } else {
            for templateExercise in template.exercises {
                modelContext.delete(templateExercise)
            }
            template.exercises.removeAll()
        }

        for (index, draft) in selectedExerciseDrafts.enumerated() {
            guard let exercise = allExercises.first(where: { $0.id == draft.exerciseID }) else { continue }
            let templateExercise = WorkoutTemplateExercise(
                orderIndex: index,
                exercise: exercise,
                exerciseNameSnapshot: exercise.name,
                plannedSetCount: max(1, draft.setCount),
                template: template
            )
            template.exercises.append(templateExercise)
            modelContext.insert(templateExercise)
        }

        try? modelContext.save()
        onSave()
    }

    private func deleteCustomExercise(_ exercise: Exercise) {
        guard exercise.isCustom else { return }

        selectedExerciseDrafts.removeAll { $0.exerciseID == exercise.id }
        newlyCreatedExercises.removeAll { $0.id == exercise.id }
        modelContext.delete(exercise)
        try? modelContext.save()
    }

    private func deleteTemplate() {
        guard let template else { return }

        modelContext.delete(template)
        try? modelContext.save()
        onDelete?()
    }
}

private struct SelectedExerciseDraft: Identifiable, Equatable {
    let exerciseID: UUID
    var setCount: Int

    var id: UUID { exerciseID }

    init(exerciseID: UUID, setCount: Int = 1) {
        self.exerciseID = exerciseID
        self.setCount = setCount
    }
}

private struct SelectedExerciseRow: View {
    let index: Int
    let exercise: Exercise
    @Binding var setCount: Int
    let onRemove: () -> Void

    var body: some View {
        HStack {
            Text("\(index + 1)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(exercise.name)

            Spacer()

            HStack(spacing: 8) {
                Button {
                    setCount = max(1, setCount - 1)
                } label: {
                    Image(systemName: "minus")
                }
                .disabled(setCount <= 1)
                .accessibilityLabel("Decrease sets for \(exercise.name)")

                Text("\(setCount)")
                    .font(.subheadline.monospacedDigit())
                    .frame(width: 36, height: 30)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: PushPassTheme.cornerRadius))
                    .accessibilityLabel("\(setCount) sets")

                Button {
                    setCount += 1
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Increase sets for \(exercise.name)")
            }
            .buttonStyle(.plain)

            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(exercise.name)")
        }
    }
}

private struct WorkoutTemplateRow: View {
    let template: WorkoutTemplate

    private var orderedExercises: [WorkoutTemplateExercise] {
        template.exercises.sorted { $0.orderIndex < $1.orderIndex }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(template.name)
                .font(.headline)
            Text("\(template.exercises.count) exercises")
                .font(.caption)
                .foregroundStyle(.secondary)
            if !orderedExercises.isEmpty {
                Text(orderedExercises.prefix(4).map(\.exerciseNameSnapshot).joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
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
        .modelContainer(for: [WorkoutTemplate.self, WorkoutTemplateExercise.self, Workout.self, WorkoutExercise.self, LiftSet.self, Exercise.self], inMemory: true)
}
