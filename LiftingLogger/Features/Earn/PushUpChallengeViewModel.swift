import Foundation
import Observation

@Observable
final class PushUpChallengeViewModel {
    var repetitionCount = 0
    var feedback = "Place the phone so your side profile is visible"
    var isLoggingComplete = false
    var errorMessage: String?
    var currentPose: BodyPose?
    var currentElbowAngle: Double?
    var currentDistanceRatio: Double?
    var isUsingDistanceFallback = false

    private var analyzer = PushUpAnalyzer()

    #if os(iOS)
    let cameraSession = CameraSessionManager()
    #endif

    init() {
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
        isLoggingComplete = false
        feedback = "Calibrating"
        errorMessage = nil
        currentPose = nil
        currentElbowAngle = nil
        currentDistanceRatio = nil
        isUsingDistanceFallback = false

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

    private func process(pose: BodyPose?) {
        guard !isLoggingComplete else { return }
        currentPose = pose
        let result = analyzer.analyze(pose: pose)
        repetitionCount = result.repetitionCount
        currentElbowAngle = result.elbowAngle
        currentDistanceRatio = result.distanceRatio
        isUsingDistanceFallback = result.usedDistanceFallback
        feedback = result.message
    }
}
