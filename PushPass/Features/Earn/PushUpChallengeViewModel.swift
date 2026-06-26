import Foundation
import Observation

@Observable
final class PushUpChallengeViewModel {
    var repetitionCount = 0
    var feedback = "Place the phone so your side profile is visible"
    var isComplete = false
    var errorMessage: String?

    let targetRepetitions: Int
    private var analyzer = PushUpAnalyzer()

    #if os(iOS)
    let cameraSession = CameraSessionManager()
    #endif

    init(targetRepetitions: Int) {
        self.targetRepetitions = targetRepetitions

        #if os(iOS)
        cameraSession.onPoseDetected = { [weak self] pose in
            self?.process(pose: pose)
        }
        cameraSession.onError = { [weak self] message in
            self?.errorMessage = message
            self?.feedback = message
        }
        #endif
    }

    func start() {
        analyzer.reset()
        repetitionCount = 0
        isComplete = false
        feedback = "Calibrating"
        errorMessage = nil

        #if os(iOS)
        cameraSession.requestAccessAndStart()
        #else
        feedback = "Camera verification requires iPhone"
        #endif
    }

    func stop() {
        #if os(iOS)
        cameraSession.stop()
        #endif
    }

    func simulateRepForDebug() {
        guard !isComplete else { return }
        repetitionCount += 1
        feedback = "Rep counted"
        isComplete = repetitionCount >= targetRepetitions
    }

    private func process(pose: BodyPose?) {
        guard !isComplete else { return }
        let result = analyzer.analyze(pose: pose)
        repetitionCount = result.repetitionCount
        feedback = result.message
        isComplete = repetitionCount >= targetRepetitions
    }
}
