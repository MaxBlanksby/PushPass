import SwiftData
import SwiftUI

struct PushUpChallengeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var modelContext
    @Query private var economySettings: [PushupEconomySettings]
    @State private var viewModel = PushUpChallengeViewModel()
    @State private var rewardMessage: String?

    private var economy: PushupEconomySettings {
        economySettings.first ?? PushupEconomySettings()
    }

    private var pendingEarnedSeconds: Int {
        viewModel.repetitionCount * economy.secondsPerPushup
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
                Text("\(viewModel.repetitionCount)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("verified push-ups")
                    .foregroundStyle(.secondary)
                Text("\(RewardService.formattedDuration(pendingEarnedSeconds)) ready to bank")
                    .font(.caption.weight(.semibold))
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

            HStack {
                Button(rewardMessage == nil ? "Cancel" : "Done") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button {
                    logPushUps(detectionMode: "camera")
                } label: {
                    Label("Log", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.repetitionCount <= 0 || rewardMessage != nil)
            }
        }
        .padding(PushPassTheme.screenPadding)
        .navigationTitle("Earn Minutes")
        .task {
            _ = RewardService.economySettings(context: modelContext)
            try? modelContext.save()
        }
        .onAppear {
            viewModel.start()
        }
        .onDisappear {
            viewModel.stop()
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

    private func logPushUps(detectionMode: String) {
        guard rewardMessage == nil else { return }
        guard viewModel.repetitionCount > 0 else { return }
        viewModel.isLoggingComplete = true
        viewModel.stop()

        let challenge = PushUpChallenge(
            completedAt: .now,
            targetRepetitions: viewModel.repetitionCount,
            completedRepetitions: viewModel.repetitionCount,
            wasSuccessful: true,
            detectionMode: detectionMode
        )
        modelContext.insert(challenge)

        do {
            let outcome = try RewardService.grantReward(for: challenge, context: modelContext)
            ScreenTimeSetupService.syncRestrictions(
                dashboard: environment.dashboard,
                accessExpirationDate: RewardService.currentActiveSession(context: modelContext)?.expirationDate
            )
            rewardMessage = outcome.explanation
        } catch {
            rewardMessage = error.localizedDescription
        }
    }
}
