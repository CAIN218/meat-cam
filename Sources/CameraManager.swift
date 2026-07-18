import AVFoundation
import CoreImage
import SwiftUI

/// カメラのキャプチャセッションを管理し、フレームを間引きながら
/// DonenessAnalyzing に渡して解析結果を @Published で公開する。
final class CameraManager: NSObject, ObservableObject {
    @Published var grid: DonenessGrid = .empty(columns: Self.gridColumns, rows: Self.gridRows)
    @Published var isAuthorized = false
    @Published var setupError: String?

    static let gridColumns = 40
    static let gridRows = 30

    let session = AVCaptureSession()

    private let analyzer: DonenessAnalyzing = HeuristicDonenessAnalyzer()
    private let videoOutputQueue = DispatchQueue(label: "MeatCam.videoOutput")

    // フルfpsで毎フレーム解析すると発熱・電池消費が大きいので間引く。
    private var frameCounter = 0
    private let analyzeEveryNFrames = 3

    func configureAndStart() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                self?.isAuthorized = granted
                guard granted else {
                    self?.setupError = "設定アプリでカメラへのアクセスを許可してください。"
                    return
                }
                self?.setupSession()
            }
        }
    }

    private func setupSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            setupError = "背面カメラを初期化できませんでした。"
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: videoOutputQueue)

        guard session.canAddOutput(output) else {
            setupError = "映像出力を初期化できませんでした。"
            session.commitConfiguration()
            return
        }
        session.addOutput(output)

        session.commitConfiguration()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    func stop() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning()
        }
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        frameCounter += 1
        guard frameCounter % analyzeEveryNFrames == 0 else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let result = analyzer.analyze(
            pixelBuffer: pixelBuffer,
            columns: Self.gridColumns,
            rows: Self.gridRows
        )

        DispatchQueue.main.async { [weak self] in
            self?.grid = result
        }
    }
}
