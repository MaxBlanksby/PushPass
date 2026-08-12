import SwiftUI

#if os(iOS)
import AVFoundation
import UIKit

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.videoPreviewLayer.session = session
    }
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        layer as? AVCaptureVideoPreviewLayer ?? AVCaptureVideoPreviewLayer()
    }
}
#else
struct CameraPreviewView: View {
    var body: some View {
        ContentUnavailableView("Camera preview is available on iPhone", systemImage: "camera")
    }
}
#endif

struct BodyPoseOverlayView: View {
    let pose: BodyPose?

    private let minimumConfidence = 0.2

    var body: some View {
        Canvas { context, size in
            guard let pose else { return }

            drawArm(
                shoulder: pose.leftShoulder,
                elbow: pose.leftElbow,
                wrist: pose.leftWrist,
                in: size,
                context: &context
            )
            drawArm(
                shoulder: pose.rightShoulder,
                elbow: pose.rightElbow,
                wrist: pose.rightWrist,
                in: size,
                context: &context
            )
        }
        .allowsHitTesting(false)
    }

    private func drawArm(
        shoulder: BodyPoseJoint?,
        elbow: BodyPoseJoint?,
        wrist: BodyPoseJoint?,
        in size: CGSize,
        context: inout GraphicsContext
    ) {
        let joints = [shoulder, elbow, wrist].compactMap { $0 }.filter { $0.confidence >= minimumConfidence }
        guard !joints.isEmpty else { return }

        if let shoulder, let elbow, shoulder.confidence >= minimumConfidence, elbow.confidence >= minimumConfidence {
            drawSegment(from: shoulder, to: elbow, in: size, context: &context)
        }

        if let elbow, let wrist, elbow.confidence >= minimumConfidence, wrist.confidence >= minimumConfidence {
            drawSegment(from: elbow, to: wrist, in: size, context: &context)
        }

        for joint in joints {
            drawJoint(joint, in: size, context: &context)
        }
    }

    private func drawSegment(
        from start: BodyPoseJoint,
        to end: BodyPoseJoint,
        in size: CGSize,
        context: inout GraphicsContext
    ) {
        var path = Path()
        path.move(to: viewPoint(for: start, in: size))
        path.addLine(to: viewPoint(for: end, in: size))
        context.stroke(path, with: .color(.green), lineWidth: 4)
    }

    private func drawJoint(_ joint: BodyPoseJoint, in size: CGSize, context: inout GraphicsContext) {
        let point = viewPoint(for: joint, in: size)
        let radius = 7.0
        let rect = CGRect(
            x: point.x - radius,
            y: point.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        context.fill(Path(ellipseIn: rect), with: .color(.yellow))
        context.stroke(Path(ellipseIn: rect), with: .color(.black.opacity(0.65)), lineWidth: 2)
    }

    private func viewPoint(for joint: BodyPoseJoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: joint.location.x * size.width,
            y: (1 - joint.location.y) * size.height
        )
    }
}
