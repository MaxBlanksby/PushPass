import Foundation

enum PushUpState: String {
    case waitingForBody
    case ready
    case up
    case movingDown
    case down
    case movingUp
    case completed
}

struct PushUpAnalyzerResult {
    let state: PushUpState
    let repetitionCount: Int
    let message: String
    let elbowAngle: Double?
    let distanceRatio: Double?
    let usedDistanceFallback: Bool
}
