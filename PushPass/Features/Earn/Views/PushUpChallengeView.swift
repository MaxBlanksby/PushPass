import SwiftData
import SwiftUI

struct PushUpChallengeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var environment
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
                    .aspectRatio(9 / 16, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: PushPassTheme.cornerRadius))

                BodyPoseOverlayView(pose: viewModel.currentPose)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(9 / 16, contentMode: .fit)
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
                Text(elbowAngleText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text(distanceSignalText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if let rewardMessage {
                Text(rewardMessage)
                    .font(.headline)
                    .foregroundStyle(.green)
            }

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

    private var elbowAngleText: String {
        guard let angle = viewModel.currentElbowAngle else {
            return "Elbow angle: --"
        }

        let phase = angle <= 90 ? "bottom" : "top"
        let formattedAngle = angle.formatted(.number.precision(.fractionLength(0)))
        return "Elbow angle: \(formattedAngle) degrees, \(phase)"
    }

    private var distanceSignalText: String {
        guard let ratio = viewModel.currentDistanceRatio else {
            return "Distance signal: --"
        }

        let formattedRatio = ratio.formatted(.number.precision(.fractionLength(2)))
        let mode = viewModel.isUsingDistanceFallback ? "fallback" : "support"
        return "Distance signal: \(formattedRatio), \(mode)"
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
            let activeSession = RewardService.currentActiveSession(context: modelContext)
            ScreenTimeSetupService.syncRestrictions(
                dashboard: environment.dashboard,
                accessExpirationDate: activeSession?.expirationDate
            )
            rewardMessage = outcome.explanation
        } catch {
            rewardMessage = error.localizedDescription
        }
    }
}
