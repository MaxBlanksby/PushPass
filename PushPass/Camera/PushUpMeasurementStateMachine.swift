import Foundation

struct PushUpMeasurementStateMachine {
    private let configuration: PushUpDetectionConfiguration
    private var phase: PushUpPhase = .waitingForBody
    private var repetitionCount = 0
    private var selectedSide: DetectedBodySide = .none
    private var smoother: PoseSmoother
    private var calibration: PushUpCalibration
    private var thresholds: PushUpThresholds
    private var mostRecentRepMetrics: PushUpRepMetrics?

    private var lastTimestamp: TimeInterval?
    private var lastValidTimestamp: TimeInterval?
    private var lastSmoothedAngle: Double?
    private var recentTrendAngles: [(timestamp: TimeInterval, angle: Double)] = []
    private var readyConditionStart: TimeInterval?
    private var upperConditionStart: TimeInterval?
    private var lowerConditionStart: TimeInterval?
    private var trackingLostStart: TimeInterval?
    private var repStartTimestamp: TimeInterval?
    private var stableDownTimestamp: TimeInterval?
    private var ascentStartTimestamp: TimeInterval?
    private var repMaximumAngle: Double?
    private var repMinimumAngle: Double?
    private var confidenceSum = 0.0
    private var confidenceSampleCount = 0
    private var minimumBodyAngleDuringRep: Double?
    private var achievedDepth = false
    private var switchedSideDuringRep = false
    private var lastCompletionTimestamp: TimeInterval?
    private var calibrationProgress = 0.0

    init(configuration: PushUpDetectionConfiguration = PushUpDetectionConfiguration()) {
        self.configuration = configuration
        self.smoother = PoseSmoother(configuration: configuration)
        self.calibration = PushUpCalibration()
        self.thresholds = PushUpThresholds.fallback(configuration: configuration)
    }

    mutating func reset() {
        phase = .waitingForBody
        repetitionCount = 0
        selectedSide = .none
        smoother.reset()
        calibration.reset()
        thresholds = PushUpThresholds.fallback(configuration: configuration)
        mostRecentRepMetrics = nil
        lastTimestamp = nil
        lastValidTimestamp = nil
        lastSmoothedAngle = nil
        recentTrendAngles.removeAll()
        clearTimers()
        resetRepProgress()
        trackingLostStart = nil
        lastCompletionTimestamp = nil
        calibrationProgress = 0
    }

    mutating func process(_ measurement: PushUpMeasurement) -> PushUpDetectionResult {
        guard measurement.timestamp > (lastTimestamp ?? -.infinity) else {
            return result(
                feedback: feedback(for: phase),
                rawAngle: measurement.elbowAngle,
                smoothedAngle: lastSmoothedAngle,
                bodyAngle: measurement.bodyAngle,
                confidence: measurement.confidence
            )
        }
        lastTimestamp = measurement.timestamp

        guard measurementIsTrackable(measurement) else {
            return handleInvalidTracking(measurement)
        }

        if let lastValidTimestamp, measurement.timestamp - lastValidTimestamp > configuration.trackingResetDuration {
            resetTrackingContinuity(keepCount: true)
        }
        lastValidTimestamp = measurement.timestamp
        trackingLostStart = nil

        if selectedSide == .none {
            selectedSide = measurement.bodySide
            log("body side selected \(selectedSide)")
        } else if measurement.bodySide != selectedSide {
            selectedSide = measurement.bodySide
            switchedSideDuringRep = true
            smoother.reset()
            recentTrendAngles.removeAll()
            cancelPartialRep(at: measurement.timestamp, feedback: .holdTopPosition)
            phase = .waitingForUp
            log("body side switched; partial rep cancelled")
        }

        guard let rawAngle = measurement.elbowAngle else {
            return result(
                feedback: .criticalJointsMissing,
                rawAngle: nil,
                smoothedAngle: lastSmoothedAngle,
                bodyAngle: measurement.bodyAngle,
                confidence: measurement.confidence
            )
        }

        let smoothedAngle = smoother.smooth(angle: rawAngle)
        let previousAngle = lastSmoothedAngle
        lastSmoothedAngle = smoothedAngle
        appendTrend(timestamp: measurement.timestamp, angle: smoothedAngle)
        recordRepSample(angle: smoothedAngle, measurement: measurement)

        switch phase {
        case .waitingForBody, .trackingLost:
            if bodyReadyCondition(measurement) {
                readyConditionStart = readyConditionStart ?? measurement.timestamp
                if elapsed(readyConditionStart, measurement.timestamp) >= configuration.bodyReadyDuration {
                    transition(to: .calibrating, angle: smoothedAngle, velocity: velocity(previousAngle, smoothedAngle, measurement.timestamp))
                    calibrationProgress = 0
                    clearPositionTimers()
                }
            } else {
                readyConditionStart = nil
            }

        case .calibrating:
            guard bodyReadyCondition(measurement), smoothedAngle >= 135 else {
                calibration.reset()
                calibrationProgress = 0
                return result(feedback: .holdTopPosition, rawAngle: rawAngle, smoothedAngle: smoothedAngle, bodyAngle: measurement.bodyAngle, confidence: measurement.confidence)
            }

            calibrationProgress = calibration.addUpperSample(smoothedAngle, at: measurement.timestamp, configuration: configuration)
            if calibration.isComplete {
                thresholds = calibration.thresholds(configuration: configuration)
                transition(to: .waitingForUp, angle: smoothedAngle, velocity: velocity(previousAngle, smoothedAngle, measurement.timestamp))
                log("calibration success up=\(thresholds.upEnter) down=\(thresholds.downEnter)")
            }

        case .waitingForUp:
            if isValidUpper(smoothedAngle, measurement: measurement, timestamp: measurement.timestamp) {
                transition(to: .stableUp, angle: smoothedAngle, velocity: velocity(previousAngle, smoothedAngle, measurement.timestamp))
            }

        case .stableUp:
            if smoothedAngle < thresholds.upExit, isDescending {
                beginRep(at: measurement.timestamp, angle: smoothedAngle, measurement: measurement)
                transition(to: .descending, angle: smoothedAngle, velocity: velocity(previousAngle, smoothedAngle, measurement.timestamp))
            }

        case .descending:
            repMinimumAngle = min(repMinimumAngle ?? smoothedAngle, smoothedAngle)
            if smoothedAngle <= thresholds.downEnter, bodyAlignmentAcceptable(measurement), descentDuration(at: measurement.timestamp) >= configuration.minimumDescentDuration {
                lowerConditionStart = lowerConditionStart ?? measurement.timestamp
                if elapsed(lowerConditionStart, measurement.timestamp) >= configuration.lowerHoldDuration {
                    achievedDepth = true
                    stableDownTimestamp = measurement.timestamp
                    transition(to: .stableDown, angle: smoothedAngle, velocity: velocity(previousAngle, smoothedAngle, measurement.timestamp))
                    clearPositionTimers()
                }
            } else {
                lowerConditionStart = nil
            }

            if smoothedAngle >= thresholds.upEnter, !achievedDepth {
                cancelPartialRep(at: measurement.timestamp, feedback: .goLower)
                transition(to: .stableUp, angle: smoothedAngle, velocity: velocity(previousAngle, smoothedAngle, measurement.timestamp))
            } else if repTimedOut(at: measurement.timestamp) {
                cancelPartialRep(at: measurement.timestamp, feedback: .holdTopPosition)
                transition(to: .waitingForUp, angle: smoothedAngle, velocity: velocity(previousAngle, smoothedAngle, measurement.timestamp))
            }

        case .stableDown:
            if smoothedAngle > thresholds.downExit, isAscending {
                ascentStartTimestamp = measurement.timestamp
                transition(to: .ascending, angle: smoothedAngle, velocity: velocity(previousAngle, smoothedAngle, measurement.timestamp))
            } else if repTimedOut(at: measurement.timestamp) {
                cancelPartialRep(at: measurement.timestamp, feedback: .straightenArms)
                transition(to: .waitingForUp, angle: smoothedAngle, velocity: velocity(previousAngle, smoothedAngle, measurement.timestamp))
            }

        case .ascending:
            if smoothedAngle >= thresholds.upEnter, bodyAlignmentAcceptable(measurement) {
                upperConditionStart = upperConditionStart ?? measurement.timestamp
                if elapsed(upperConditionStart, measurement.timestamp) >= configuration.upperHoldDuration {
                    completeRepIfValid(at: measurement.timestamp, angle: smoothedAngle, measurement: measurement, previousAngle: previousAngle)
                }
            } else {
                upperConditionStart = nil
            }

            if repTimedOut(at: measurement.timestamp) {
                cancelPartialRep(at: measurement.timestamp, feedback: .straightenArms)
                transition(to: .waitingForUp, angle: smoothedAngle, velocity: velocity(previousAngle, smoothedAngle, measurement.timestamp))
            }

        case .completedRep:
            transition(to: .stableUp, angle: smoothedAngle, velocity: velocity(previousAngle, smoothedAngle, measurement.timestamp))
        }

        return result(
            feedback: feedback(for: phase),
            rawAngle: rawAngle,
            smoothedAngle: smoothedAngle,
            bodyAngle: measurement.bodyAngle,
            confidence: measurement.confidence
        )
    }

    private mutating func handleInvalidTracking(_ measurement: PushUpMeasurement) -> PushUpDetectionResult {
        trackingLostStart = trackingLostStart ?? measurement.timestamp
        let lostDuration = elapsed(trackingLostStart, measurement.timestamp)

        if lostDuration > configuration.trackingResetDuration {
            resetTrackingContinuity(keepCount: true)
            phase = .waitingForBody
        } else if lostDuration > configuration.trackingGraceDuration {
            if phase == .descending || phase == .stableDown || phase == .ascending {
                resetRepProgress()
            }
            phase = .trackingLost
        }

        return result(
            feedback: measurement.bodySide == .none ? .noPersonDetected : .criticalJointsMissing,
            rawAngle: measurement.elbowAngle,
            smoothedAngle: lastSmoothedAngle,
            bodyAngle: measurement.bodyAngle,
            confidence: measurement.confidence
        )
    }

    private func measurementIsTrackable(_ measurement: PushUpMeasurement) -> Bool {
        measurement.criticalJointsVisible
            && measurement.confidence >= Double(configuration.minimumJointConfidence)
            && measurement.bodySide != .none
            && measurement.elbowAngle != nil
    }

    private func bodyReadyCondition(_ measurement: PushUpMeasurement) -> Bool {
        measurementIsTrackable(measurement) && bodyAlignmentAcceptable(measurement)
    }

    private func bodyAlignmentAcceptable(_ measurement: PushUpMeasurement) -> Bool {
        guard let bodyAngle = measurement.bodyAngle else { return true }
        return bodyAngle >= configuration.minimumBodyAngle
    }

    private mutating func isValidUpper(_ angle: Double, measurement: PushUpMeasurement, timestamp: TimeInterval) -> Bool {
        let condition = angle >= thresholds.upEnter && bodyAlignmentAcceptable(measurement) && abs(currentVelocity) <= 35
        if condition {
            upperConditionStart = upperConditionStart ?? timestamp
        } else {
            upperConditionStart = nil
        }
        return elapsed(upperConditionStart, timestamp) >= configuration.upperHoldDuration
    }

    private mutating func beginRep(at timestamp: TimeInterval, angle: Double, measurement: PushUpMeasurement) {
        repStartTimestamp = timestamp
        repMaximumAngle = angle
        repMinimumAngle = angle
        confidenceSum = measurement.confidence
        confidenceSampleCount = 1
        minimumBodyAngleDuringRep = measurement.bodyAngle
        achievedDepth = false
        switchedSideDuringRep = false
        stableDownTimestamp = nil
        ascentStartTimestamp = nil
        clearPositionTimers()
    }

    private mutating func recordRepSample(angle: Double, measurement: PushUpMeasurement) {
        guard repStartTimestamp != nil else { return }
        repMaximumAngle = max(repMaximumAngle ?? angle, angle)
        repMinimumAngle = min(repMinimumAngle ?? angle, angle)
        confidenceSum += measurement.confidence
        confidenceSampleCount += 1
        if let bodyAngle = measurement.bodyAngle {
            minimumBodyAngleDuringRep = min(minimumBodyAngleDuringRep ?? bodyAngle, bodyAngle)
        }
    }

    private mutating func completeRepIfValid(at timestamp: TimeInterval, angle: Double, measurement: PushUpMeasurement, previousAngle: Double?) {
        guard let repStartTimestamp,
              achievedDepth,
              !switchedSideDuringRep,
              lastCompletionTimestamp != timestamp else {
            return
        }

        let totalDuration = timestamp - repStartTimestamp
        guard totalDuration >= configuration.minimumRepDuration, totalDuration <= configuration.maximumRepDuration else {
            cancelPartialRep(at: timestamp, feedback: totalDuration < configuration.minimumRepDuration ? .lowerBody : .straightenArms)
            transition(to: .waitingForUp, angle: angle, velocity: velocity(previousAngle, angle, timestamp))
            return
        }

        guard (repMinimumAngle ?? 180) <= thresholds.downEnter, (repMaximumAngle ?? 0) >= thresholds.upExit else {
            cancelPartialRep(at: timestamp, feedback: .goLower)
            transition(to: .waitingForUp, angle: angle, velocity: velocity(previousAngle, angle, timestamp))
            return
        }

        let descent = (stableDownTimestamp ?? timestamp) - repStartTimestamp
        let bottomPause = max(0, (ascentStartTimestamp ?? timestamp) - (stableDownTimestamp ?? timestamp))
        let ascent = max(0, timestamp - (ascentStartTimestamp ?? timestamp))
        mostRecentRepMetrics = PushUpRepMetrics(
            minimumElbowAngle: repMinimumAngle ?? angle,
            maximumElbowAngle: max(repMaximumAngle ?? angle, angle),
            descentDuration: descent,
            bottomPauseDuration: bottomPause,
            ascentDuration: ascent,
            totalDuration: totalDuration,
            averageJointConfidence: confidenceSampleCount == 0 ? 0 : confidenceSum / Double(confidenceSampleCount),
            minimumBodyLineAngle: minimumBodyAngleDuringRep
        )

        repetitionCount += 1
        lastCompletionTimestamp = timestamp
        resetRepProgress()
        transition(to: .completedRep, angle: angle, velocity: velocity(previousAngle, angle, timestamp))
    }

    private mutating func cancelPartialRep(at timestamp: TimeInterval, feedback: PushUpFeedback) {
        log("incomplete rep \(feedback.rawValue) at \(timestamp)")
        resetRepProgress()
        clearPositionTimers()
    }

    private mutating func resetTrackingContinuity(keepCount: Bool) {
        let count = repetitionCount
        let recentMetrics = mostRecentRepMetrics
        phase = .waitingForBody
        selectedSide = .none
        smoother.reset()
        calibration.reset()
        thresholds = PushUpThresholds.fallback(configuration: configuration)
        lastValidTimestamp = nil
        lastSmoothedAngle = nil
        recentTrendAngles.removeAll()
        clearTimers()
        resetRepProgress()
        calibrationProgress = 0
        if keepCount {
            repetitionCount = count
            mostRecentRepMetrics = recentMetrics
        }
    }

    private mutating func resetRepProgress() {
        repStartTimestamp = nil
        stableDownTimestamp = nil
        ascentStartTimestamp = nil
        repMaximumAngle = nil
        repMinimumAngle = nil
        confidenceSum = 0
        confidenceSampleCount = 0
        minimumBodyAngleDuringRep = nil
        achievedDepth = false
        switchedSideDuringRep = false
    }

    private mutating func clearTimers() {
        readyConditionStart = nil
        upperConditionStart = nil
        lowerConditionStart = nil
        trackingLostStart = nil
    }

    private mutating func clearPositionTimers() {
        upperConditionStart = nil
        lowerConditionStart = nil
    }

    private mutating func appendTrend(timestamp: TimeInterval, angle: Double) {
        recentTrendAngles.append((timestamp, angle))
        recentTrendAngles = Array(recentTrendAngles.suffix(5))
    }

    private var currentVelocity: Double {
        guard recentTrendAngles.count >= 2 else { return 0 }
        let first = recentTrendAngles[recentTrendAngles.count - 2]
        let last = recentTrendAngles[recentTrendAngles.count - 1]
        let duration = max(last.timestamp - first.timestamp, 0.001)
        return (last.angle - first.angle) / duration
    }

    private var isDescending: Bool {
        currentVelocity < -configuration.angularVelocityThreshold || trendDelta <= -4
    }

    private var isAscending: Bool {
        currentVelocity > configuration.angularVelocityThreshold || trendDelta >= 4
    }

    private var trendDelta: Double {
        guard let first = recentTrendAngles.first?.angle, let last = recentTrendAngles.last?.angle else { return 0 }
        return last - first
    }

    private func velocity(_ previousAngle: Double?, _ angle: Double, _ timestamp: TimeInterval) -> Double {
        guard previousAngle != nil else { return 0 }
        return currentVelocity
    }

    private func elapsed(_ start: TimeInterval?, _ timestamp: TimeInterval) -> TimeInterval {
        guard let start else { return 0 }
        return max(0, timestamp - start)
    }

    private func descentDuration(at timestamp: TimeInterval) -> TimeInterval {
        guard let repStartTimestamp else { return 0 }
        return timestamp - repStartTimestamp
    }

    private func repTimedOut(at timestamp: TimeInterval) -> Bool {
        guard let repStartTimestamp else { return false }
        return timestamp - repStartTimestamp > configuration.maximumRepDuration
    }

    private mutating func transition(to nextPhase: PushUpPhase, angle: Double?, velocity: Double) {
        guard phase != nextPhase else { return }
        #if DEBUG
        let oldPhase = phase
        #endif
        phase = nextPhase
        #if DEBUG
        print("PushUpAnalyzer: \(oldPhase.rawValue) -> \(nextPhase.rawValue) angle=\(Int(angle ?? -1)) velocity=\(Int(velocity))")
        #endif
    }

    private func feedback(for phase: PushUpPhase) -> PushUpFeedback {
        switch phase {
        case .waitingForBody:
            return .noPersonDetected
        case .calibrating, .waitingForUp:
            return .holdTopPosition
        case .stableUp:
            return .ready
        case .descending:
            return .lowerBody
        case .stableDown:
            return .pushBackUp
        case .ascending:
            return .straightenArms
        case .completedRep:
            return .repCounted
        case .trackingLost:
            return .criticalJointsMissing
        }
    }

    private func result(
        feedback: PushUpFeedback,
        rawAngle: Double?,
        smoothedAngle: Double?,
        bodyAngle: Double?,
        confidence: Double
    ) -> PushUpDetectionResult {
        let repProgress: Double
        if let smoothedAngle {
            let span = max(thresholds.upEnter - thresholds.downEnter, 1)
            repProgress = min(1, max(0, (thresholds.upEnter - smoothedAngle) / span))
        } else {
            repProgress = 0
        }

        return PushUpDetectionResult(
            phase: phase,
            repetitionCount: repetitionCount,
            feedback: feedback,
            selectedSide: selectedSide,
            rawElbowAngle: rawAngle,
            smoothedElbowAngle: smoothedAngle,
            bodyAlignmentAngle: bodyAngle,
            averageConfidence: confidence,
            calibrationProgress: calibrationProgress,
            repProgress: repProgress,
            mostRecentRepMetrics: mostRecentRepMetrics
        )
    }

    private func log(_ message: String) {
        #if DEBUG
        print("PushUpAnalyzer: \(message)")
        #endif
    }
}
