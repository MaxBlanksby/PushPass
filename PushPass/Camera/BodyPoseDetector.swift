import Foundation

#if os(iOS)
import Vision

enum BodyPoseDetector {
    static func detectPose(in pixelBuffer: CVPixelBuffer) throws -> BodyPose? {
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right)
        try handler.perform([request])
        guard let observation = request.results?.first else { return nil }

        let points = try observation.recognizedPoints(.all)
        return BodyPose(
            leftShoulder: joint(points[.leftShoulder]),
            leftElbow: joint(points[.leftElbow]),
            leftWrist: joint(points[.leftWrist]),
            leftHip: joint(points[.leftHip]),
            rightShoulder: joint(points[.rightShoulder]),
            rightElbow: joint(points[.rightElbow]),
            rightWrist: joint(points[.rightWrist]),
            rightHip: joint(points[.rightHip])
        )
    }

    private static func joint(_ point: VNRecognizedPoint?) -> BodyPoseJoint? {
        guard let point else { return nil }
        return BodyPoseJoint(location: point.location, confidence: Double(point.confidence))
    }
}
#endif
