import Foundation

#if os(iOS)
import AVFoundation

final class CameraSessionManager: NSObject {
    let session = AVCaptureSession()
    var onPoseDetected: ((BodyPose?) -> Void)?
    var onError: ((String) -> Void)?

    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "PushPass.CameraSession")
    private var isConfigured = false

    func requestAccessAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            start()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    granted ? self?.start() : self?.onError?("Camera permission denied")
                }
            }
        case .denied, .restricted:
            onError?("Camera permission denied")
        @unknown default:
            onError?("Camera authorization unavailable")
        }
    }

    func start() {
        queue.async {
            do {
                if !self.isConfigured {
                    try self.configure()
                }
                if !self.session.isRunning {
                    self.session.startRunning()
                }
            } catch {
                DispatchQueue.main.async {
                    self.onError?("Camera unavailable")
                }
            }
        }
    }

    func stop() {
        queue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    private func configure() throws {
        session.beginConfiguration()
        session.sessionPreset = .high
        defer { session.commitConfiguration() }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) ??
            AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CameraSessionError.noCamera
        }

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else { throw CameraSessionError.cannotAddInput }
        session.addInput(input)

        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else { throw CameraSessionError.cannotAddOutput }
        session.addOutput(output)
        output.connection(with: .video)?.videoRotationAngle = 90

        isConfigured = true
    }
}

extension CameraSessionManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let pose = try? BodyPoseDetector.detectPose(in: pixelBuffer)
        DispatchQueue.main.async {
            self.onPoseDetected?(pose)
        }
    }
}

private enum CameraSessionError: Error {
    case noCamera
    case cannotAddInput
    case cannotAddOutput
}
#endif
