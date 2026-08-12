import CoreGraphics
import Foundation

struct BodyPoseJoint {
    let location: CGPoint
    let confidence: Double
}

struct BodyPose {
    var leftShoulder: BodyPoseJoint?
    var leftElbow: BodyPoseJoint?
    var leftWrist: BodyPoseJoint?
    var rightShoulder: BodyPoseJoint?
    var rightElbow: BodyPoseJoint?
    var rightWrist: BodyPoseJoint?

    var strongestArm: PushUpArmSample? {
        let left = sample(shoulder: leftShoulder, elbow: leftElbow, wrist: leftWrist)
        let right = sample(shoulder: rightShoulder, elbow: rightElbow, wrist: rightWrist)

        switch (left, right) {
        case let (left?, right?):
            return left.averageConfidence >= right.averageConfidence ? left : right
        case let (left?, nil):
            return left
        case let (nil, right?):
            return right
        case (nil, nil):
            return nil
        }
    }

    private func sample(
        shoulder: BodyPoseJoint?,
        elbow: BodyPoseJoint?,
        wrist: BodyPoseJoint?
    ) -> PushUpArmSample? {
        guard let elbow, let wrist else { return nil }
        return PushUpArmSample(shoulder: shoulder, elbow: elbow, wrist: wrist)
    }
}

struct PushUpArmSample {
    let shoulder: BodyPoseJoint?
    let elbow: BodyPoseJoint
    let wrist: BodyPoseJoint

    var averageConfidence: Double {
        let values = [shoulder?.confidence, elbow.confidence, wrist.confidence].compactMap(\.self)
        return values.reduce(0, +) / Double(values.count)
    }
}
