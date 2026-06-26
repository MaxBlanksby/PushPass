import SwiftUI

struct WorkoutsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                    } label: {
                        Label("Start Empty Workout", systemImage: "plus.circle.fill")
                    }
                    .disabled(true)
                } footer: {
                    Text("Workout creation and set logging start in the SwiftData workout phase.")
                }

                Section("History") {
                    ContentUnavailableView("No Workouts Yet", systemImage: "dumbbell")
                }
            }
            .navigationTitle("Workouts")
        }
    }
}

#Preview {
    WorkoutsView()
}
