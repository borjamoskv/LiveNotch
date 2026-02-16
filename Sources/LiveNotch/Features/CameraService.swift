import AVFoundation
import SwiftUI

// ═══════════════════════════════════════════════════
// MARK: - 📷 Camera Service (Mirror Feature)
// ═══════════════════════════════════════════════════

class CameraService: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var isAuthorized = false
    
    private let sessionQueue = DispatchQueue(label: "com.livenotch.camera")
    
    override init() {
        super.init()
        checkPermissions()
    }
    
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            self.isAuthorized = true
            setupCamera()
        case .notDetermined:
            // CAMERA PERMISSION DISABLED AS REQUESTED
            NSLog("📷 CameraService: Access disabled (Simulation Mode)")
            self.isAuthorized = false
        default:
            self.isAuthorized = false
        }
    }
    
    func setupCamera() {
        sessionQueue.async {
            self.session.beginConfiguration()
            
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) ??
                               AVCaptureDevice.default(for: .video) else {
                NSLog("📷 CameraService: No camera found")
                self.session.commitConfiguration()
                return
            }
            
            do {
                let input = try AVCaptureDeviceInput(device: device)
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                }
            } catch {
                NSLog("📷 CameraService: Error setting up camera input — %@", error.localizedDescription)
            }
            
            self.session.commitConfiguration()
        }
    }
    
    func start() {
        sessionQueue.async {
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }
    
    func stop() {
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }
}

// ═══════════════════════════════════════════════════
// MARK: - Camera Preview (NSViewRepresentable)
// ═══════════════════════════════════════════════════

struct CameraPreview: NSViewRepresentable {
    @ObservedObject var cameraService: CameraService
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: cameraService.session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        previewLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        
        // Mirror the preview for natural selfie look
        previewLayer.setAffineTransform(CGAffineTransform(scaleX: -1, y: 1))
        
        view.layer = previewLayer
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let layer = nsView.layer as? AVCaptureVideoPreviewLayer {
            layer.session = cameraService.session
        }
    }
}
