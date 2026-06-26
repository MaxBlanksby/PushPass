import SwiftData
import SwiftUI

struct PushUpChallengeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var preferences: [UserPreferences]
    @State private var viewModel: PushUpChallengeViewModel
    @State private var rewardMessage: String?

    init(targetRepetitions: Int) {
        _viewModel = State(initialValue: PushUpChallengeViewModel(targetRepetitions: targetRepetitions))
    }

    var body: some View {
        VStack(spacing: 20) {
            ZStack(alignment: .bottom) {
                #if os(iOS)
                CameraPreviewView(session: viewModel.cameraSession.session)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(3 / 4, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: PushPassTheme.cornerRadius))
                #else
                CameraPreviewView()
                    .frame(maxWidth: .infinity, minHeight: 320)
                #endif

                Text(viewModel.feedback)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.ultraThinMaterial)
            }

            VStack(spacing: 8) {
                Text("\(viewModel.repetitionCount) / \(viewModel.targetRepetitions)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("verified push-ups")
                    .foregroundStyle(.secondary)
            }

            if let rewardMessage {
                Text(rewardMessage)
                    .font(.headline)
                    .foregroundStyle(.green)
            }

            #if DEBUG
            Button {
                viewModel.simulateRepForDebug()
                if viewModel.isComplete {
                    completeChallenge(detectionMode: "debug-simulated")
                }
            } label: {
                Label("Simulate Rep", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            #endif

            Button(viewModel.isComplete ? "Done" : "Cancel") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(PushPassTheme.screenPadding)
        .navigationTitle("Push-up Challenge")
        .onAppear {
            viewModel.start()
        }
        .onDisappear {
            viewModel.stop()
        }
        .onChange(of: viewModel.isComplete) { _, isComplete in
            if isComplete {
                completeChallenge(detectionMode: "camera")
            }
        }
    }

    private func completeChallenge(detectionMode: String) {
        guard rewardMessage == nil else { return }

        let prefs = preferences.first ?? UserPreferences()
        if preferences.isEmpty {
            modelContext.insert(prefs)
        }

        let challenge = PushUpChallenge(
            completedAt: .now,
            targetRepetitions: viewModel.targetRepetitions,
            completedRepetitions: viewModel.repetitionCount,
            wasSuccessful: true,
            detectionMode: detectionMode
        )
        modelContext.insert(challenge)

        do {
            let outcome = try RewardService.grantReward(for: challenge, preferences: prefs, context: modelContext)
            rewardMessage = outcome.explanation
        } catch {
            rewardMessage = error.localizedDescription
        }
    }
}
