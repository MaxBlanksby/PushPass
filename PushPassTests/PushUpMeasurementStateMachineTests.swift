import Testing
@testable import PushPass

struct PushUpMeasurementStateMachineTests {
    @Test func normalRepCountsExactlyOnce() {
        let result = runSequence(calibratedTop() + normalRep(start: 2.4))
        #expect(result.repetitionCount == 1)
    }

    @Test func twoNormalRepsCountExactlyTwice() {
        let result = runSequence(calibratedTop() + normalRep(start: 2.4) + normalRep(start: 5.5))
        #expect(result.repetitionCount == 2)
    }

    @Test func partialRepDoesNotCount() {
        let result = runSequence(calibratedTop() + partialRep(start: 2.4))
        #expect(result.repetitionCount == 0)
    }

    @Test func startingAtBottomDoesNotCountInitialRise() {
        let sequence = bottomStart() + calibratedTop(start: 1.6) + normalRep(start: 4.0)
        let result = runSequence(sequence)
        #expect(result.repetitionCount == 1)
    }

    @Test func bouncingNearUpperThresholdDoesNotCount() {
        var sequence = calibratedTop()
        sequence += samples(start: 2.4, step: 0.1, angles: [158, 153, 150, 156, 151, 159, 154, 150, 157, 152])
        let result = runSequence(sequence)
        #expect(result.repetitionCount == 0)
    }

    @Test func bouncingNearLowerThresholdCountsAtMostOnce() {
        var sequence = calibratedTop()
        sequence += samples(start: 2.4, step: 0.1, angles: [155, 145, 132, 116, 101, 94, 88, 102, 91, 98, 85, 96, 112, 130, 148, 160, 165, 165, 165, 165, 165, 165])
        let result = runSequence(sequence)
        #expect(result.repetitionCount <= 1)
    }

    @Test func fastInvalidMotionDoesNotCount() {
        let fastCycle = samples(start: 2.4, step: 0.04, angles: [165, 140, 105, 80, 115, 145, 165, 165, 165])
        let result = runSequence(calibratedTop() + fastCycle)
        #expect(result.repetitionCount == 0)
    }

    @Test func slowControlledRepCounts() {
        let slow = samples(start: 2.4, step: 0.25, angles: [165, 160, 152, 144, 136, 126, 116, 106, 96, 88, 82, 80, 82, 90, 100, 112, 124, 136, 148, 158, 164, 165, 165, 165, 165, 165])
        let result = runSequence(calibratedTop() + slow)
        #expect(result.repetitionCount == 1)
    }

    @Test func trackingLossDuringDescentCancelsPartialRep() {
        var sequence = calibratedTop()
        sequence += samples(start: 2.4, step: 0.1, angles: [165, 152, 140, 128])
        sequence += invalidSamples(start: 2.8, step: 0.1, count: 10)
        sequence += samples(start: 3.9, step: 0.1, angles: [85, 95, 120, 145, 165, 165, 165, 165, 165, 165, 165, 165])
        let result = runSequence(sequence)
        #expect(result.repetitionCount == 0)
        #expect(result.phase == .waitingForBody || result.phase == .calibrating || result.phase == .waitingForUp)
    }

    @Test func oneInvalidFrameDoesNotResetOtherwiseValidRep() {
        var sequence = calibratedTop()
        sequence += samples(start: 2.4, step: 0.1, angles: [165, 154, 142, 130, 116])
        sequence.append(measurement(timestamp: 2.9, angle: nil, confidence: 0.1, visible: false))
        sequence += samples(start: 3.0, step: 0.1, angles: [102, 92, 84, 80, 80, 92, 110, 130, 148, 160, 165, 165, 165, 165, 165, 165, 165, 165])
        let result = runSequence(sequence)
        #expect(result.repetitionCount == 1)
    }

    @Test func sideSwitchDuringRepCancelsRep() {
        var sequence = calibratedTop(side: .left)
        sequence += samples(start: 2.4, step: 0.1, angles: [165, 152, 138, 120, 102, 88, 80], side: .left)
        sequence += samples(start: 3.1, step: 0.1, angles: [92, 110, 130, 150, 165, 165, 165, 165], side: .right)
        let result = runSequence(sequence)
        #expect(result.repetitionCount == 0)
    }

    @Test func duplicateTimestampsAreIgnored() {
        var machine = PushUpMeasurementStateMachine()
        var last = PushUpDetectionResult.placeholder
        for sample in calibratedTop() + normalRep(start: 2.4) {
            last = machine.process(sample)
            _ = machine.process(sample)
        }
        #expect(last.repetitionCount == 1)
    }

    @Test func outOfOrderFrameIsIgnored() {
        var machine = PushUpMeasurementStateMachine()
        var last = PushUpDetectionResult.placeholder
        for sample in calibratedTop() + normalRep(start: 2.4) {
            last = machine.process(sample)
            if sample.timestamp > 3.5 {
                _ = machine.process(measurement(timestamp: sample.timestamp - 0.5, angle: 120))
            }
        }
        #expect(last.repetitionCount == 1)
    }

    @Test func foldedBodyDoesNotCount() {
        let sequence = calibratedTop(bodyAngle: 170) + normalRep(start: 2.4, bodyAngle: 130)
        let result = runSequence(sequence)
        #expect(result.repetitionCount == 0)
        #expect(result.feedback == .holdTopPosition || result.feedback == .straightenArms || result.feedback == .lowerBody)
    }

    @Test func jitterAroundValidRepCountsOnce() {
        let noisyAngles = [165, 160, 151, 145, 133, 119, 105, 96, 85, 82, 78, 84, 93, 109, 124, 139, 151, 160, 166, 163, 165, 166, 165, 165, 165, 165, 165]
        let result = runSequence(calibratedTop() + samples(start: 2.4, step: 0.12, angles: noisyAngles))
        #expect(result.repetitionCount == 1)
    }

    @Test func longBottomHoldCountsAfterReturnToTop() {
        var sequence = calibratedTop()
        sequence += samples(start: 2.4, step: 0.1, angles: [165, 152, 138, 120, 102, 88, 80])
        sequence += samples(start: 3.1, step: 0.3, angles: Array(repeating: 80, count: 10))
        sequence += samples(start: 6.2, step: 0.1, angles: [92, 110, 130, 148, 160, 165, 165, 165, 165, 165, 165, 165, 165])
        let result = runSequence(sequence)
        #expect(result.repetitionCount == 1)
    }

    @Test func neverReturnsToTopDoesNotCount() {
        var sequence = calibratedTop()
        sequence += samples(start: 2.4, step: 0.1, angles: [165, 152, 138, 120, 102, 88, 80, 82, 96, 112, 126, 135, 135, 135, 135])
        let result = runSequence(sequence)
        #expect(result.repetitionCount == 0)
        #expect(result.feedback == .straightenArms)
    }

    @Test func repAfterTrackingResetCountsAfterReestablishingTop() {
        var sequence = calibratedTop()
        sequence += samples(start: 2.4, step: 0.1, angles: [165, 152, 138])
        sequence += invalidSamples(start: 2.8, step: 0.1, count: 10)
        sequence += calibratedTop(start: 4.0)
        sequence += normalRep(start: 6.4)
        let result = runSequence(sequence)
        #expect(result.repetitionCount == 1)
    }
}

private func runSequence(_ sequence: [PushUpMeasurement]) -> PushUpDetectionResult {
    var machine = PushUpMeasurementStateMachine()
    var result = PushUpDetectionResult.placeholder
    for sample in sequence {
        result = machine.process(sample)
    }
    return result
}

private func calibratedTop(start: TimeInterval = 0, side: DetectedBodySide = .left, bodyAngle: Double = 170) -> [PushUpMeasurement] {
    samples(start: start, step: 0.1, angles: Array(repeating: 165, count: 24), side: side, bodyAngle: bodyAngle)
}

private func normalRep(start: TimeInterval, bodyAngle: Double = 170) -> [PushUpMeasurement] {
    samples(
        start: start,
        step: 0.1,
        angles: [165, 160, 152, 144, 134, 122, 110, 98, 88, 80, 80, 82, 94, 112, 130, 146, 158, 165, 165, 165, 165, 165, 165, 165, 165, 165, 165],
        bodyAngle: bodyAngle
    )
}

private func partialRep(start: TimeInterval) -> [PushUpMeasurement] {
    samples(start: start, step: 0.1, angles: [165, 158, 150, 142, 132, 124, 120, 124, 136, 148, 158, 165, 165, 165])
}

private func bottomStart() -> [PushUpMeasurement] {
    samples(start: 0, step: 0.1, angles: [80, 84, 96, 114, 132, 150, 165, 165, 165, 165])
}

private func samples(
    start: TimeInterval,
    step: TimeInterval,
    angles: [Double],
    side: DetectedBodySide = .left,
    bodyAngle: Double = 170
) -> [PushUpMeasurement] {
    angles.enumerated().map { index, angle in
        measurement(
            timestamp: start + Double(index) * step,
            angle: angle,
            bodyAngle: bodyAngle,
            side: side
        )
    }
}

private func invalidSamples(start: TimeInterval, step: TimeInterval, count: Int) -> [PushUpMeasurement] {
    (0..<count).map { index in
        measurement(
            timestamp: start + Double(index) * step,
            angle: nil,
            confidence: 0.1,
            side: .none,
            visible: false
        )
    }
}

private func measurement(
    timestamp: TimeInterval,
    angle: Double?,
    bodyAngle: Double? = 170,
    confidence: Double = 0.9,
    side: DetectedBodySide = .left,
    visible: Bool = true
) -> PushUpMeasurement {
    PushUpMeasurement(
        timestamp: timestamp,
        elbowAngle: angle,
        bodyAngle: bodyAngle,
        confidence: confidence,
        bodySide: side,
        criticalJointsVisible: visible
    )
}

private extension PushUpDetectionResult {
    static var placeholder: PushUpDetectionResult {
        PushUpDetectionResult(
            phase: .waitingForBody,
            repetitionCount: 0,
            feedback: .noPersonDetected,
            selectedSide: .none,
            rawElbowAngle: nil,
            smoothedElbowAngle: nil,
            bodyAlignmentAngle: nil,
            averageConfidence: 0,
            calibrationProgress: 0,
            repProgress: 0,
            mostRecentRepMetrics: nil
        )
    }
}
