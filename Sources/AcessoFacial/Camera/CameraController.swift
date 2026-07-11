import Foundation
@preconcurrency import AVFoundation
import CoreImage
import CoreGraphics
import Combine

/// Controla a câmera via AVFoundation (nativo) e publica o quadro mais recente.
@MainActor
final class CameraController: NSObject, ObservableObject {
    @Published var latestImage: CGImage?
    @Published var authorized = false
    @Published var running = false
    @Published var errorMessage: String?
    @Published var availableDevices: [AVCaptureDevice] = []
    @Published var selectedDeviceID: String?

    let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "camera.frames")

    func requestAndStart() {
        refreshDevices()
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            authorized = true
            configureAndRun()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    self?.authorized = granted
                    if granted { self?.configureAndRun() }
                    else { self?.errorMessage = "Acesso à câmera negado." }
                }
            }
        default:
            authorized = false
            errorMessage = "Câmera não autorizada. Ajustes → Privacidade → Câmera."
        }
    }

    func refreshDevices() {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera],
            mediaType: .video, position: .unspecified)
        availableDevices = discovery.devices
        if selectedDeviceID == nil { selectedDeviceID = availableDevices.first?.uniqueID }
    }

    func switchCamera(to deviceID: String) {
        selectedDeviceID = deviceID
        guard authorized else { return }
        configureAndRun()
    }

    private func configureAndRun() {
        session.beginConfiguration()
        for input in session.inputs { session.removeInput(input) }
        session.sessionPreset = .high

        let device = availableDevices.first(where: { $0.uniqueID == selectedDeviceID })
            ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            ?? AVCaptureDevice.default(for: .video)

        guard let device, let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            errorMessage = "Nenhuma câmera disponível."
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(output) { session.addOutput(output) }

        session.commitConfiguration()
        queue.async { [session] in
            if !session.isRunning { session.startRunning() }
            Task { @MainActor in self.running = true }
        }
    }

    func stop() {
        queue.async { [session] in
            if session.isRunning { session.stopRunning() }
            Task { @MainActor in self.running = false }
        }
    }

    func snapshot() -> CGImage? { latestImage }
}

extension CameraController: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput,
                                   didOutput sampleBuffer: CMSampleBuffer,
                                   from connection: AVCaptureConnection) {
        guard let pb = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ci = CIImage(cvPixelBuffer: pb)
        let ctx = CIContext(options: nil)
        guard let cg = ctx.createCGImage(ci, from: ci.extent) else { return }
        Task { @MainActor in self.latestImage = cg }
    }
}
