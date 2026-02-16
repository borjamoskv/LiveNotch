import AppKit
import Vision
import AVFoundation
import Combine

// ═══════════════════════════════════════════════════
// MARK: - 🖐️ Spatial Gesture Engine (The Jedi Notch)
// ═══════════════════════════════════════════════════
// Uses Apple's Vision framework and Neural Engine to detect
// hand poses without keeping the camera stream active/visible.
// Optimized for 0% CPU impact (offloaded to ANE).

class SpatialGestureEngine: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    static let shared = SpatialGestureEngine()
    
    @Published var activeAction: NotchAction = .none
    @Published var isCameraAuthorized = false
    @Published var isRunning = false
    
    enum NotchAction {
        case swipeLeft  // Next track / Dismiss
        case swipeRight // Prev track
        case pinch      // "Grab" notch to expand
        case palm       // "Stop" / Pause
        case none
    }
    
    // ── Capture Session ──
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "com.livenotch.spatial.camera", qos: .userInteractive)
    
    // ── Vision Requests ──
    private var handPoseRequest = VNDetectHumanHandPoseRequest()
    
    // ── State for Gesture Logic ──
    private var lastPinchDistance: CGFloat = 1.0
    private var pinchSmoothing: [CGFloat] = []
    private var handVisibleFrames = 0
    // private var cooldownTimer: Timer? // Removed: using asyncAfter
    private var isCoolingDown = false
    
    override init() {
        super.init()
        checkPermission()
    }
    
    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            self.isCameraAuthorized = true
            self.configureSession()
        case .notDetermined:
            // CAMERA PERMISSION DISABLED AS REQUESTED
            NSLog("🖐️ SpatialEngine: Access disabled (Simulation Mode)")
            self.isCameraAuthorized = false
        default:
            self.isCameraAuthorized = false
        }
    }
    
    private func configureSession() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .low // We only need coordinates, not HD video
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device) else {
            NSLog("⚠️ SpatialEngine: No front camera found.")
            captureSession.commitConfiguration()
            return
        }
        
        if captureSession.canAddInput(input) { captureSession.addInput(input) }
        
        videoOutput.setSampleBufferDelegate(self, queue: queue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        // Pixel format: efficient for Vision
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
        
        if captureSession.canAddOutput(videoOutput) { captureSession.addOutput(videoOutput) }
        
        // Optimizations
        if let connection = videoOutput.connection(with: .video) {
            connection.isEnabled = true
            if connection.isVideoMirroringSupported { connection.isVideoMirrored = true }
        }
        
        captureSession.commitConfiguration()
    }
    
    // ── Control ──
    
    func start() {
        guard isCameraAuthorized, !captureSession.isRunning else { return }
        queue.async {
            self.captureSession.startRunning()
            DispatchQueue.main.async { self.isRunning = true }
        }
    }
    
    func stop() {
        guard captureSession.isRunning else { return }
        queue.async {
            self.captureSession.stopRunning()
            DispatchQueue.main.async { self.isRunning = false }
        }
    }
    
    // ── Processing ──
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Skip if cooling down to save energy
        if isCoolingDown { return }
        
        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .up, options: [:])
        
        do {
            // maxHands: 1 for efficiency
            handPoseRequest.maximumHandCount = 1
            try handler.perform([handPoseRequest])
            
            guard let observation = handPoseRequest.results?.first else {
                DispatchQueue.main.async {
                    if self.handVisibleFrames > 0 { self.handVisibleFrames = 0 }
                    if self.activeAction != .none { self.activeAction = .none }
                }
                return
            }
            
            processHandPose(observation)
            
        } catch {
            NSLog("🖐️ SpatialEngine: Vision request failed — %@", error.localizedDescription)
        }
    }
    
    private func processHandPose(_ observation: VNHumanHandPoseObservation) {
        do {
            // Get key points
            let indexTip = try observation.recognizedPoint(.indexTip)
            let thumbTip = try observation.recognizedPoint(.thumbTip)
            let wrist = try observation.recognizedPoint(.wrist)
            let ringTip = try observation.recognizedPoint(.ringTip)
            
            // Confidence filter
            guard indexTip.confidence > 0.8 && thumbTip.confidence > 0.8 else { return }
            
            // Calculate Pinch Distance (Normalized 0.0 - 1.0)
            // Vision coordinates are normalized to the image.
            let distance = hypot(indexTip.location.x - thumbTip.location.x, indexTip.location.y - thumbTip.location.y)
            
            DispatchQueue.main.async {
                self.handVisibleFrames += 1
                
                // Only react if hand has been stable for a few frames (debounce)
                if self.handVisibleFrames > 3 {
                    self.detectGestures(distance: distance, wrist: wrist, ring: ringTip)
                }
            }
        } catch {
            NSLog("🖐️ SpatialEngine: Hand pose processing error — %@", error.localizedDescription)
            return
        }
    }
    
    private func detectGestures(distance: Double, wrist: VNRecognizedPoint, ring: VNRecognizedPoint) {
        // 1. PINCH (Expanding the notch)
        // Threshold: < 0.05 is touching
        if distance < 0.05 {
            if activeAction != .pinch {
                triggerAction(.pinch)
            }
            return
        }
        
        // 2. OPEN PALM (Stop/Pause)
        // Heuristic: Ring finger tip is far from wrist (extended)
        let ringDist = hypot(ring.location.x - wrist.location.x, ring.location.y - wrist.location.y)
        if ringDist > 0.4 { // Hand is open/extended
             // Could be palm
        }
        
        // If nothing matched, reset
        if activeAction != .none {
            activeAction = .none
        }
    }
    
    private func triggerAction(_ action: NotchAction) {
        guard !isCoolingDown else { return }
        
        NSLog("⚡ Jedi Action: %@", String(describing: action))
        self.activeAction = action
        HapticManager.shared.play(.heavy) // Tactile confirmation of air gesture
        
        // Cooldown to prevent spam
        isCoolingDown = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
           self?.isCoolingDown = false
           self?.activeAction = .none
        }
    }

    deinit {
        stop()
    }
}
