import Foundation

enum DetectedBodySide: Equatable {
    case left
    case right
    case none
}

enum PushUpPhase: String, Equatable {
    case waitingForBody
    case calibrating
    case waitingForUp
    case stableUp
    case descending
    case stableDown
    case ascending
    case completedRep
    case trackingLost
}

enum PushUpFeedback: String, Equatable {
    case cameraUnavailable = "Camera unavailable"
    case noPersonDetected = "No person detected"
    case criticalJointsMissing = "Keep your shoulder, elbow, wrist, and hip visible"
    case moveFullyIntoFrame = "Move fully into frame"
    case turnSideways = "Turn sideways"
    case holdTopPosition = "Hold the top position"
    case ready = "Ready"
    case lowerBody = "Lower your body"
    case goLower = "Go lower"
    case pushBackUp = "Push back up"
    case straightenArms = "Straighten your arms"
    case repCounted = "Rep counted"
}

struct PushUpDetectionConfiguration {
    let minimumJointConfidence: Float
    let bodyReadyDuration: TimeInterval
    let calibrationDuration: TimeInterval
    let upperHoldDuration: TimeInterval
    let lowerHoldDuration: TimeInterval
    let trackingGraceDuration: TimeInterval
    let trackingResetDuration: TimeInterval
    let minimumRepDuration: TimeInterval
    let maximumRepDuration: TimeInterval
    let minimumDescentDuration: TimeInterval
    let smoothingWindowSize: Int
    let smoothingAlpha: Double
    let minimumBodyAngle: Double
    let minimumShoulderHipDistance: Double
    let fallbackUpEnterAngle: Double
    let fallbackUpExitAngle: Double
    let fallbackDownEnterAngle: Double
    let fallbackDownExitAngle: Double
    let minimumThresholdGap: Double
    let angularVelocityThreshold: Double

    init(
        minimumJointConfidence: Float = 0.45,
        bodyReadyDuration: TimeInterval = 0.75,
        calibrationDuration: TimeInterval = 1.0,
        upperHoldDuration: TimeInterval = 0.25,
        lowerHoldDuration: TimeInterval = 0.15,
        trackingGraceDuration: TimeInterval = 0.20,
        trackingResetDuration: TimeInterval = 0.75,
        minimumRepDuration: TimeInterval = 0.7,
        maximumRepDuration: TimeInterval = 10.0,
        minimumDescentDuration: TimeInterval = 0.30,
        smoothingWindowSize: Int = 5,
        smoothingAlpha: Double = 0.35,
        minimumBodyAngle: Double = 145,
        minimumShoulderHipDistance: Double = 0.08,
        fallbackUpEnterAngle: Double = 155,
        fallbackUpExitAngle: Double = 140,
        fallbackDownEnterAngle: Double = 95,
        fallbackDownExitAngle: Double = 110,
        minimumThresholdGap: Double = 35,
        angularVelocityThreshold: Double = 8
    ) {
        self.minimumJointConfidence = minimumJointConfidence
        self.bodyReadyDuration = bodyReadyDuration
        self.calibrationDuration = calibrationDuration
        self.upperHoldDuration = upperHoldDuration
        self.lowerHoldDuration = lowerHoldDuration
        self.trackingGraceDuration = trackingGraceDuration
        self.trackingResetDuration = trackingResetDuration
        self.minimumRepDuration = minimumRepDuration
        self.maximumRepDuration = maximumRepDuration
        self.minimumDescentDuration = minimumDescentDuration
        self.smoothingWindowSize = max(1, smoothingWindowSize)
        self.smoothingAlpha = min(max(smoothingAlpha, 0), 1)
        self.minimumBodyAngle = minimumBodyAngle
        self.minimumShoulderHipDistance = minimumShoulderHipDistance
        self.fallbackUpEnterAngle = fallbackUpEnterAngle
        self.fallbackUpExitAngle = fallbackUpExitAngle
        self.fallbackDownEnterAngle = fallbackDownEnterAngle
        self.fallbackDownExitAngle = fallbackDownExitAngle
        self.minimumThresholdGap = minimumThresholdGap
        self.angularVelocityThreshold = angularVelocityThreshold
    }
}

struct PushUpMeasurement {
    let timestamp: TimeInterval
    let elbowAngle: Double?
    let bodyAngle: Double?
    let confidence: Double
    let bodySide: DetectedBodySide
    let criticalJointsVisible: Bool
}

struct PushUpRepMetrics: Equatable {
    let minimumElbowAngle: Double
    let maximumElbowAngle: Double
    let descentDuration: TimeInterval
    let bottomPauseDuration: TimeInterval
    let ascentDuration: TimeInterval
    let totalDuration: TimeInterval
    let averageJointConfidence: Double
    let minimumBodyLineAngle: Double?
}

struct PushUpDetectionResult {
    let phase: PushUpPhase
    let repetitionCount: Int
    let feedback: PushUpFeedback
    let selectedSide: DetectedBodySide
    let rawElbowAngle: Double?
    let smoothedElbowAngle: Double?
    let bodyAlignmentAngle: Double?
    let averageConfidence: Double
    let calibrationProgress: Double
    let repProgress: Double
    let mostRecentRepMetrics: PushUpRepMetrics?
}

struct PushUpCalibration {
    private(set) var upAngle: Double?
    private(set) var downAngle: Double?
    private var upperSamples: [Double] = []
    private var startedAt: TimeInterval?

    var isComplete: Bool { upAngle != nil }

    mutating func reset() {
        upAngle = nil
        downAngle = nil
        upperSamples.removeAll()
        startedAt = nil
    }

    mutating func addUpperSample(_ angle: Double, at timestamp: TimeInterval, configuration: PushUpDetectionConfiguration) -> Double {
        if startedAt == nil {
            startedAt = timestamp
        }
        upperSamples.append(angle)
        upperSamples = Array(upperSamples.suffix(max(3, Int(configuration.calibrationDuration * 20))))

        let progress = min(1, (timestamp - (startedAt ?? timestamp)) / configuration.calibrationDuration)
        if progress >= 1, let median = upperSamples.median(), (135...180).contains(median), sampleSpread <= 14 {
            upAngle = median
        }
        return progress
    }

    func thresholds(configuration: PushUpDetectionConfiguration) -> PushUpThresholds {
        guard let upAngle else {
            return PushUpThresholds.fallback(configuration: configuration)
        }

        var upEnter = max(145, upAngle - 10)
        var upExit = upEnter - 12
        var downEnter = min(100, upAngle - 55)
        var downExit = downEnter + 12

        if let downAngle {
            downEnter = downAngle + 8
            downExit = downEnter + 12
        }

        if downEnter >= upExit || upExit - downEnter < configuration.minimumThresholdGap {
            return PushUpThresholds.fallback(configuration: configuration)
        }

        upEnter = min(180, max(0, upEnter))
        upExit = min(180, max(0, upExit))
        downEnter = min(180, max(0, downEnter))
        downExit = min(180, max(0, downExit))
        return PushUpThresholds(
            upEnter: upEnter,
            upExit: upExit,
            downEnter: downEnter,
            downExit: downExit
        )
    }

    private var sampleSpread: Double {
        guard let min = upperSamples.min(), let max = upperSamples.max() else { return .infinity }
        return max - min
    }
}

struct PushUpThresholds: Equatable {
    let upEnter: Double
    let upExit: Double
    let downEnter: Double
    let downExit: Double

    static func fallback(configuration: PushUpDetectionConfiguration) -> PushUpThresholds {
        PushUpThresholds(
            upEnter: configuration.fallbackUpEnterAngle,
            upExit: configuration.fallbackUpExitAngle,
            downEnter: configuration.fallbackDownEnterAngle,
            downExit: configuration.fallbackDownExitAngle
        )
    }
}

struct PoseSmoother {
    private let configuration: PushUpDetectionConfiguration
    private var recentAngles: [Double] = []
    private var previousSmoothedAngle: Double?

    init(configuration: PushUpDetectionConfiguration) {
        self.configuration = configuration
    }

    mutating func reset() {
        recentAngles.removeAll()
        previousSmoothedAngle = nil
    }

    mutating func smooth(angle: Double) -> Double {
        recentAngles.append(angle)
        recentAngles = Array(recentAngles.suffix(configuration.smoothingWindowSize))

        let median = recentAngles.median() ?? angle
        let smoothed: Double
        if let previousSmoothedAngle {
            smoothed = configuration.smoothingAlpha * median + (1 - configuration.smoothingAlpha) * previousSmoothedAngle
        } else {
            smoothed = median
        }
        previousSmoothedAngle = smoothed
        return smoothed
    }
}

private extension Array where Element == Double {
    func median() -> Double? {
        guard !isEmpty else { return nil }
        let sorted = sorted()
        let midpoint = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[midpoint - 1] + sorted[midpoint]) / 2
        }
        return sorted[midpoint]
    }
}
