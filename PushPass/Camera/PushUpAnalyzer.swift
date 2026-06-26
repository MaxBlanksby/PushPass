import CoreGraphics
import Foundation

struct PushUpAnalyzer {
    var upAngleThreshold: Double = 155
    var downAngleThreshold: Double = 95
    var minimumConfidence: Double = 0.35
    var minimumRepDuration: TimeInterval = 0.45
    var maximumRepDuration: TimeInterval = 8

    private(set) var state: PushUpState = .waitingForBody
    private(set) var repetitionCount = 0
    private var smoothedAngle: Double?
    private var repStartDate: Date?
    private var lastRepDate: Date?

    mutating func reset() {
        state = .waitingForBody
        repetitionCount = 0
        smoothedAngle = nil
        repStartDate = nil
        lastRepDate = nil
    }

    mutating func analyze(pose: BodyPose?, at date: Date = .now) -> PushUpAnalyzerResult {
        guard let sample = pose?.strongestArm, sample.averageConfidence >= minimumConfidence else {
            state = .waitingForBody
            return PushUpAnalyzerResult(state: state, repetitionCount: repetitionCount, message: "Keep your shoulders, elbows, wrists, and hips visible")
        }

        let angle = Self.elbowAngle(shoulder: sample.shoulder.location, elbow: sample.elbow.location, wrist: sample.wrist.location)
        let smoothed = smooth(angle)

        switch state {
        case .waitingForBody, .ready:
            if smoothed >= upAngleThreshold {
                state = .up
                return result("Ready")
            }
            state = .ready
            return result("Push back up")

        case .up:
            if smoothed < upAngleThreshold {
                state = .movingDown
                repStartDate = date
                return result("Lower your body")
            }
            return result("Ready")

        case .movingDown:
            if smoothed <= downAngleThreshold {
                state = .down
                return result("Push back up")
            }
            return result("Lower your body")

        case .down:
            if smoothed > downAngleThreshold {
                state = .movingUp
                return result("Push back up")
            }
            return result("Push back up")

        case .movingUp:
            if smoothed >= upAngleThreshold, isValidRepDuration(at: date) {
                repetitionCount += 1
                state = .completed
                lastRepDate = date
                return result("Rep counted")
            }
            if let repStartDate, date.timeIntervalSince(repStartDate) > maximumRepDuration {
                state = .ready
                self.repStartDate = nil
                return result("Hold still")
            }
            return result("Push back up")

        case .completed:
            state = .up
            repStartDate = nil
            return result("Ready")
        }
    }

    private mutating func smooth(_ angle: Double) -> Double {
        let next: Double
        if let smoothedAngle {
            next = smoothedAngle * 0.72 + angle * 0.28
        } else {
            next = angle
        }
        smoothedAngle = next
        return next
    }

    private func isValidRepDuration(at date: Date) -> Bool {
        guard let repStartDate else { return false }
        let duration = date.timeIntervalSince(repStartDate)
        if let lastRepDate, date.timeIntervalSince(lastRepDate) < 0.35 {
            return false
        }
        return duration >= minimumRepDuration && duration <= maximumRepDuration
    }

    private func result(_ message: String) -> PushUpAnalyzerResult {
        PushUpAnalyzerResult(state: state, repetitionCount: repetitionCount, message: message)
    }

    static func elbowAngle(shoulder: CGPoint, elbow: CGPoint, wrist: CGPoint) -> Double {
        let vectorA = CGVector(dx: shoulder.x - elbow.x, dy: shoulder.y - elbow.y)
        let vectorB = CGVector(dx: wrist.x - elbow.x, dy: wrist.y - elbow.y)
        let dot = vectorA.dx * vectorB.dx + vectorA.dy * vectorB.dy
        let magnitudeA = sqrt(vectorA.dx * vectorA.dx + vectorA.dy * vectorA.dy)
        let magnitudeB = sqrt(vectorB.dx * vectorB.dx + vectorB.dy * vectorB.dy)
        guard magnitudeA > 0, magnitudeB > 0 else { return 0 }

        let cosine = max(-1, min(1, dot / (magnitudeA * magnitudeB)))
        return acos(cosine) * 180 / .pi
    }
}
