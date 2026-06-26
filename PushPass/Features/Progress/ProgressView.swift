import SwiftUI

struct ProgressView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Summary") {
                    LabeledContent("Total workouts", value: "0")
                    LabeledContent("Current streak", value: "0 days")
                    LabeledContent("Total push-ups", value: "0")
                    LabeledContent("Total minutes earned", value: "0")
                }

                Section("Exercise History") {
                    ContentUnavailableView("No Exercise Data", systemImage: "chart.xyaxis.line")
                }
            }
            .navigationTitle("Progress")
        }
    }
}

#Preview {
    ProgressView()
}
