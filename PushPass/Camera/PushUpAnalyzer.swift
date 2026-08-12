import CoreGraphics
import Foundation

struct PushUpAnalyzer {
    var topAngleThreshold: Double = 90
    var bottomAngleThreshold: Double = 90
    var minimumConfidence: Double = 0.2
    var minimumRepDuration: TimeInterval = 0.2
    var maximumRepDuration: TimeInterval = 8
    var maximumMissedPoseFrames = 8
    var distanceBottomRatio: Double = 0.72
    var distanceTopRatio: Double = 0.9

    private(set) var state: PushUpState = .waitingForBody
    private(set) var repetitionCount = 0
    private var smoothedAngle: Double?
    private var smoothedDistanceRatio: Double?
    private var repStartDate: Date?
    private var lastRepDate: Date?
    private var missedPoseFrames = 0
    private var topDistanceBaseline: Double?

    mutating func reset() {
        state = .waitingForBody
        repetitionCount = 0
        smoothedAngle = nil
        smoothedDistanceRatio = nil
        repStartDate = nil
        lastRepDate = nil
        missedPoseFrames = 0
        topDistanceBaseline = nil
    }

    mutating func analyze(pose: BodyPose?, at date: Date = .now) -> PushUpAnalyzerResult {
        guard let sample = pose?.strongestArm, sample.averageConfidence >= minimumConfidence else {
            missedPoseFrames += 1

            if missedPoseFrames > maximumMissedPoseFrames {
                state = .waitingForBody
                repStartDate = nil
                smoothedAngle = nil
                smoothedDistanceRatio = nil
            }

            return result(
                "Keep one elbow and wrist visible",
                elbowAngle: smoothedAngle,
                distanceRatio: smoothedDistanceRatio,
                usedDistanceFallback: smoothedAngle == nil
            )
        }

        missedPoseFrames = 0
        let signal = movementSignal(from: sample)

        switch state {
        case .waitingForBody, .ready:
            if signal.isTop {
                state = .up
                updateTopDistanceBaseline(from: sample)
                return result("Top half", signal: signal)
            }
            state = .down
            repStartDate = date
            return result("Bottom half", signal: signal)

        case .up:
            updateTopDistanceBaseline(from: sample)
            if signal.isBottom {
                state = .down
                repStartDate = date
                return result("Bottom half", signal: signal)
            }
            return result("Top half", signal: signal)

        case .movingDown:
            if signal.isBottom {
                state = .down
                repStartDate = repStartDate ?? date
                return result("Bottom half", signal: signal)
            }
            return result("Lower your body", signal: signal)

        case .down:
            if signal.isTop {
                updateTopDistanceBaseline(from: sample)
                if isValidRepDuration(at: date) {
                    repetitionCount += 1
                    state = .completed
                    lastRepDate = date
                    repStartDate = nil
                    return result("Rep counted", signal: signal)
                }

                state = .up
                repStartDate = nil
                return result("Top half", signal: signal)
            }
            return result("Bottom half", signal: signal)

        case .movingUp:
            if signal.isTop, isValidRepDuration(at: date) {
                updateTopDistanceBaseline(from: sample)
                repetitionCount += 1
                state = .completed
                lastRepDate = date
                repStartDate = nil
                return result("Rep counted", signal: signal)
            }
            if let repStartDate, date.timeIntervalSince(repStartDate) > maximumRepDuration {
                state = .ready
                self.repStartDate = nil
                return result("Hold still", signal: signal)
            }
            return result("Push back up", signal: signal)

        case .completed:
            if signal.isBottom {
                state = .down
                repStartDate = date
                return result("Bottom half", signal: signal)
            }

            state = .up
            updateTopDistanceBaseline(from: sample)
            return result("Top half", signal: signal)
        }
    }

    private mutating func movementSignal(from sample: PushUpArmSample) -> PushUpMovementSignal {
        let elbowWristDistance = Self.distance(sample.elbow.location, sample.wrist.location)
        let shoulderWristDistance = sample.shoulder.map { Self.distance($0.location, sample.wrist.location) }
        let rawRatio = shoulderWristDistance.map { shoulderDistance in
            shoulderDistance / max(elbowWristDistance, 0.001)
        } ?? topDistanceBaseline.map { baseline in
            elbowWristDistance / max(baseline, 0.001)
        }

        let distanceRatio = rawRatio.map { smoothDistanceRatio($0) }

        if let shoulder = sample.shoulder, shoulder.confidence >= minimumConfidence {
            let angle = Self.elbowAngle(shoulder: shoulder.location, elbow: sample.elbow.location, wrist: sample.wrist.location)
            let smoothedAngle = smoothAngle(angle)
            return PushUpMovementSignal(
                elbowAngle: smoothedAngle,
                distanceRatio: distanceRatio,
                isBottom: smoothedAngle <= bottomAngleThreshold,
                isTop: smoothedAngle > topAngleThreshold,
                usedDistanceFallback: false
            )
        }

        guard let distanceRatio else {
            return PushUpMovementSignal(
                elbowAngle: smoothedAngle,
                distanceRatio: nil,
                isBottom: state == .down,
                isTop: state == .up || state == .completed,
                usedDistanceFallback: true
            )
        }

        return PushUpMovementSignal(
            elbowAngle: smoothedAngle,
            distanceRatio: distanceRatio,
            isBottom: distanceRatio <= distanceBottomRatio,
            isTop: distanceRatio >= distanceTopRatio,
            usedDistanceFallback: true
        )
    }

    private mutating func smoothAngle(_ angle: Double) -> Double {
        let next: Double
        if let smoothedAngle {
            next = smoothedAngle * 0.45 + angle * 0.55
        } else {
            next = angle
        }
        smoothedAngle = next
        return next
    }

    private mutating func smoothDistanceRatio(_ ratio: Double) -> Double {
        let next: Double
        if let smoothedDistanceRatio {
            next = smoothedDistanceRatio * 0.45 + ratio * 0.55
        } else {
            next = ratio
        }
        smoothedDistanceRatio = next
        return next
    }

    private mutating func updateTopDistanceBaseline(from sample: PushUpArmSample) {
        let distance = Self.distance(sample.elbow.location, sample.wrist.location)
        guard distance > 0 else { return }

        if let topDistanceBaseline {
            self.topDistanceBaseline = max(topDistanceBaseline, distance)
        } else {
            topDistanceBaseline = distance
        }
    }

    private func isValidRepDuration(at date: Date) -> Bool {
        guard let repStartDate else { return false }
        let duration = date.timeIntervalSince(repStartDate)
        if let lastRepDate, date.timeIntervalSince(lastRepDate) < 0.35 {
            return false
        }
        return duration >= minimumRepDuration && duration <= maximumRepDuration
    }

    private func result(_ message: String, signal: PushUpMovementSignal) -> PushUpAnalyzerResult {
        result(
            message,
            elbowAngle: signal.elbowAngle,
            distanceRatio: signal.distanceRatio,
            usedDistanceFallback: signal.usedDistanceFallback
        )
    }

    private func result(
        _ message: String,
        elbowAngle: Double?,
        distanceRatio: Double?,
        usedDistanceFallback: Bool
    ) -> PushUpAnalyzerResult {
        PushUpAnalyzerResult(
            state: state,
            repetitionCount: repetitionCount,
            message: message,
            elbowAngle: elbowAngle,
            distanceRatio: distanceRatio,
            usedDistanceFallback: usedDistanceFallback
        )
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

    static func distance(_ first: CGPoint, _ second: CGPoint) -> Double {
        let dx = first.x - second.x
        let dy = first.y - second.y
        return sqrt(dx * dx + dy * dy)
    }
}

private struct PushUpMovementSignal {
    let elbowAngle: Double?
    let distanceRatio: Double?
    let isBottom: Bool
    let isTop: Bool
    let usedDistanceFallback: Bool
}
