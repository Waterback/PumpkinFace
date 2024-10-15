import SwiftUI
import AVFoundation
import Vision

struct ContentView: View {
    @StateObject private var cameraViewModel = CameraViewModel()
    
    var body: some View {
        ZStack {
            // Kameraansicht
            CameraView(viewModel: cameraViewModel)
                .edgesIgnoringSafeArea(.all)
            
            // Zeige Kürbisbilder auf erkannten Gesichtern
            ForEach(cameraViewModel.faces, id: \.self) { face in
                Image("pumpkin")
                    .resizable()
                    .frame(width: face.width * UIScreen.main.bounds.width + 100,
                           height: face.height * UIScreen.main.bounds.height + 100)
                    .position(x: face.x * UIScreen.main.bounds.width + (face.width * UIScreen.main.bounds.width / 2),
                              y: (1 - face.y - 0.1) * UIScreen.main.bounds.height - (face.height * UIScreen.main.bounds.height / 2))
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

struct FaceData: Hashable {
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
}

class CameraViewModel: NSObject, ObservableObject {
    @Published var faces: [FaceData] = []
    
    public let session = AVCaptureSession()
    private var videoOutput = AVCaptureVideoDataOutput()
    
    func startSession() {
        setupCamera()
        session.startRunning()
    }
    
    func stopSession() {
        session.stopRunning()
    }
    
    private func setupCamera() {
        guard let videoCaptureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else { return }
        
        session.beginConfiguration()
        session.sessionPreset = .high
        
        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
        }
        
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }
        
        if let connection = videoOutput.connection(with: .video) {
            connection.videoOrientation = .portrait // Ignoriere die Geräteausrichtung
        }
        
        session.commitConfiguration()
    }
}

extension CameraViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let request = VNDetectFaceRectanglesRequest { [weak self] request, _ in
            guard let results = request.results as? [VNFaceObservation] else { return }
            
            DispatchQueue.main.async {
                self?.faces = results.map { face in
                    return FaceData(
                        x: face.boundingBox.origin.x,
                        y: face.boundingBox.origin.y,
                        width: face.boundingBox.size.width,
                        height: face.boundingBox.size.height
                    )
                }
            }
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        try? handler.perform([request])
    }
}

struct CameraView: UIViewRepresentable {
    let viewModel: CameraViewModel
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        let previewLayer = AVCaptureVideoPreviewLayer(session: viewModel.session)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) { }
}

