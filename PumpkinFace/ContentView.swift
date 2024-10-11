import SwiftUI
import AVFoundation
import Vision

struct ContentView: View {
    @StateObject var cameraViewModel = CameraViewModel()

    var body: some View {
        ZStack {
            CameraView(cameraViewModel: cameraViewModel)
                .edgesIgnoringSafeArea(.all)

            if let overlayImage = cameraViewModel.overlayImage {
                Image(uiImage: overlayImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                    .clipped()
            }
        }
        .onAppear {
            cameraViewModel.startSession()
        }
        .onDisappear {
            cameraViewModel.stopSession()
        }
    }
}

class CameraViewModel: NSObject, ObservableObject {
    public var session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let pumpkinImage = UIImage(named: "pumpkin")! // Add a pumpkin image in your assets
    
    @Published var overlayImage: UIImage?

    override init() {
        super.init()
        configureSession()
    }

    private func configureSession() {
        session.beginConfiguration()
        
        // Ändere die Kamera auf die Rückseitenkamera
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice),
              session.canAddInput(videoDeviceInput) else { return }
        
        session.addInput(videoDeviceInput)
        
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        }

        session.commitConfiguration()
    }

    func startSession() {
        if !session.isRunning {
            session.startRunning()
        }
    }

    func stopSession() {
        if session.isRunning {
            session.stopRunning()
        }
    }
}

extension CameraViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        let faceDetectionRequest = VNDetectFaceRectanglesRequest { [weak self] request, error in
            if let results = request.results as? [VNFaceObservation], let self = self {
                if let result = results.first {
                    self.addPumpkinToFace(on: pixelBuffer, faceObservation: result)
                }
            }
        }

        try? imageRequestHandler.perform([faceDetectionRequest])
    }

    private func addPumpkinToFace(on pixelBuffer: CVPixelBuffer, faceObservation: VNFaceObservation) {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()

        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        let uiImage = UIImage(cgImage: cgImage)

        // Bildrotation korrigieren
        let rotatedImage = UIImage(cgImage: cgImage, scale: uiImage.scale, orientation: .right)

        // Berechne das Gesichtsfeld
        let boundingBox = faceObservation.boundingBox
        let faceRect = CGRect(
            x: boundingBox.origin.x * CGFloat(cgImage.width),
            y: (1 - boundingBox.origin.y - boundingBox.height) * CGFloat(cgImage.height),
            width: boundingBox.width * CGFloat(cgImage.width),
            height: boundingBox.height * CGFloat(cgImage.height)
        )

        // Kürbis auf das Gesicht legen
        UIGraphicsBeginImageContextWithOptions(rotatedImage.size, false, 1.0)
        rotatedImage.draw(in: CGRect(x: 0, y: 0, width: rotatedImage.size.width, height: rotatedImage.size.height))
        pumpkinImage.draw(in: faceRect)

        let finalImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        DispatchQueue.main.async {
            self.overlayImage = finalImage
        }
    }
}

struct CameraView: UIViewRepresentable {
    var cameraViewModel: CameraViewModel

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        let previewLayer = AVCaptureVideoPreviewLayer(session: cameraViewModel.session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

