import AVFoundation
import CoreMedia
import QuartzCore
import UIKit
import Vision

/// Front camera capture + Vision body pose on every frame.
///
/// The video output connection is rotated to portrait and mirrored, and the very same
/// buffers are rendered into `displayLayer` — so the skeleton is always pixel-aligned
/// with what the user sees, on device and in the simulator's injected webcam.
nonisolated final class PoseCameraService: NSObject, @unchecked Sendable {
    enum StartResult: Sendable {
        case running
        case noCamera
        case failed
    }

    let displayLayer: AVSampleBufferDisplayLayer = {
        let layer = AVSampleBufferDisplayLayer()
        layer.videoGravity = .resizeAspectFill
        layer.backgroundColor = UIColor.black.cgColor
        return layer
    }()

    /// Called on the video queue for every analysed frame.
    var onFrame: (@Sendable (PoseFrame) -> Void)?

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "pose.session")
    private let videoQueue = DispatchQueue(label: "pose.video", qos: .userInteractive)
    private let visionQueue = DispatchQueue(label: "pose.vision", qos: .userInitiated)
    private let busyLock = NSLock()
    private var isAnalyzing = false
    private let output = AVCaptureVideoDataOutput()
    private let poseRequest = VNDetectHumanBodyPoseRequest()
    private var isConfigured = false
    private let minimumConfidence: Float = 0.25

    func start(completion: @escaping @Sendable (StartResult) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.isConfigured {
                let result = self.configure()
                guard result == .running else {
                    completion(result)
                    return
                }
                self.isConfigured = true
            }
            if !self.session.isRunning {
                self.session.startRunning()
            }
            completion(.running)
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    private func configure() -> StartResult {
        guard let device = Self.frontCamera() else { return .noCamera }
        guard let input = try? AVCaptureDeviceInput(device: device) else { return .failed }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        if session.canSetSessionPreset(.hd1280x720) {
            session.sessionPreset = .hd1280x720
        } else if session.canSetSessionPreset(.high) {
            session.sessionPreset = .high
        }

        guard session.canAddInput(input) else { return .failed }
        session.addInput(input)

        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: videoQueue)
        guard session.canAddOutput(output) else { return .failed }
        session.addOutput(output)

        if let connection = output.connection(with: .video) {
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = true
            }
        }
        return .running
    }

    /// Prefers the built-in front camera; falls back to any camera, including the
    /// external device the cloud simulator injects from the user's webcam.
    private static func frontCamera() -> AVCaptureDevice? {
        let front = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInTrueDepthCamera],
            mediaType: .video,
            position: .front
        ).devices.first
        if let front { return front }

        var types: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera]
        types.append(.external)
        return AVCaptureDevice.DiscoverySession(
            deviceTypes: types,
            mediaType: .video,
            position: .unspecified
        ).devices.first
    }

    private func render(_ sampleBuffer: CMSampleBuffer) {
        if let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: true),
           CFArrayGetCount(attachments) > 0 {
            let dictionary = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0), to: CFMutableDictionary.self)
            CFDictionarySetValue(
                dictionary,
                Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
                Unmanaged.passUnretained(kCFBooleanTrue).toOpaque()
            )
        }
        let renderer = displayLayer.sampleBufferRenderer
        if renderer.status == .failed || renderer.requiresFlushToResumeDecoding {
            renderer.flush()
        }
        renderer.enqueue(sampleBuffer)
    }

    private func detectPose(in pixelBuffer: CVPixelBuffer, timestamp: Double) -> PoseFrame {
        let size = CGSize(
            width: CVPixelBufferGetWidth(pixelBuffer),
            height: CVPixelBufferGetHeight(pixelBuffer)
        )
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        do {
            try handler.perform([poseRequest])
        } catch {
            return PoseFrame(joints: [:], imageSize: size, timestamp: timestamp)
        }

        let observations = poseRequest.results ?? []
        var best: [Joint: CGPoint] = [:]
        for observation in observations {
            guard let points = try? observation.recognizedPoints(.all) else { continue }
            var joints: [Joint: CGPoint] = [:]
            for joint in Joint.allCases {
                guard let point = points[joint.visionName], point.confidence >= minimumConfidence else { continue }
                joints[joint] = CGPoint(x: point.location.x, y: 1 - point.location.y)
            }
            if joints.count > best.count {
                best = joints
            }
        }
        return PoseFrame(joints: best, imageSize: size, timestamp: timestamp)
    }
}

extension PoseCameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Display every frame immediately; run Vision on its own queue and skip frames
        // while it's busy so the preview never stutters.
        render(sampleBuffer)
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        busyLock.lock()
        let isBusy = isAnalyzing
        if !isBusy { isAnalyzing = true }
        busyLock.unlock()
        guard !isBusy else { return }

        visionQueue.async { [weak self] in
            guard let self else { return }
            let frame = self.detectPose(in: pixelBuffer, timestamp: CACurrentMediaTime())
            self.busyLock.lock()
            self.isAnalyzing = false
            self.busyLock.unlock()
            self.onFrame?(frame)
        }
    }
}
