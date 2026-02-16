import SwiftUI
import AVFoundation
import Vision
import Combine

// ═══════════════════════════════════════════════════
// MARK: - 👁️ GestureEye Engine v2 — Pure Eye Control
// ═══════════════════════════════════════════════════
//
// Controls music with your EYES only. No head movement needed.
//
// • Right wink   → Next track
// • Left wink    → Previous track
// • Slow blink   → Play/Pause
//
// Uses Eye Aspect Ratio (EAR) from Vision face landmarks.
// Runs at 320×240 15fps — minimal battery impact.

enum FaceGesture: String {
    case rightWink   // right eye closed, left open
    case leftWink    // left eye closed, right open
    case slowBlink   // both eyes closed 0.4s - 1.2s (music control)
    case longBlink   // both eyes closed > 1.2s (summon Kimi)
    case handPinch   // thumb + index tap (play/pause)
    case handSwipeLeft  // hand moves left rapidly (prev track)
    case handSwipeRight // hand moves right rapidly (next track)
    case none
}

final class GestureEyeEngine: NSObject, ObservableObject {
    static let shared = GestureEyeEngine()
    
    // ── Sensitivity Modes ──
    enum Sensitivity: String, CaseIterable {
        case sensitive = "Sensitive"
        case normal = "Normal"
        case relaxed = "Relaxed"
        
        var winkMin: TimeInterval {
            switch self {
            case .sensitive: return 0.08
            case .normal: return 0.12
            case .relaxed: return 0.20
            }
        }
        var winkMax: TimeInterval {
            switch self {
            case .sensitive: return 1.0
            case .normal: return 0.8
            case .relaxed: return 0.6
            }
        }
        var blinkMin: TimeInterval {
            switch self {
            case .sensitive: return 0.2
            case .normal: return 0.3
            case .relaxed: return 0.5
            }
        }
        var cooldown: TimeInterval {
            switch self {
            case .sensitive: return 1.0
            case .normal: return 1.5
            case .relaxed: return 2.0
            }
        }
        var closedRatio: CGFloat {
            switch self {
            case .sensitive: return 0.60
            case .normal: return 0.55
            case .relaxed: return 0.50
            }
        }
    }
    
    // ── Published State ──
    // ── Persistent Config ──
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "gestureEyeEnabled") }
        set { 
            UserDefaults.standard.set(newValue, forKey: "gestureEyeEnabled") 
            DispatchQueue.main.async { self.objectWillChange.send() }
        }
    }
    
    // ── Published State ──
    @Published var isActive: Bool = false
    @Published var faceDetected: Bool = false
    @Published var lastGesture: FaceGesture = .none
    @Published var gestureFlash: Bool = false
    @Published var sensitivity: Sensitivity = .normal
    
    // ── Calibration ──
    @Published var calibrationProgress: Double = 0.0
    @Published var isCalibrated: Bool = false
    
    // ── Stats ──
    @Published var gestureCount: Int = 0
    @Published var cooldownRemaining: Double = 0.0
    
    // ── Face Quality ──
    @Published var faceConfidence: Float = 0.0
    
    // ── Eye Detection Config ──
    private let earClosedThreshold: CGFloat = 0.18   // EAR below this = eye closed
    private let earOpenThreshold: CGFloat = 0.22     // EAR above this = eye open
    private let slowBlinkMaxDuration: TimeInterval = 2.0  // max so normal sleep doesn't trigger
    private let noFaceTimeout: TimeInterval = 30.0
    
    // ── Internal State ──
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private let processingQueue = DispatchQueue(label: "com.livenotch.gestureeye", qos: .userInteractive)
    
    private var lastGestureTime = Date.distantPast
    private var lastFaceSeenTime = Date()
    private var consecutiveNoFaceFrames: Int = 0
    private var frameCount: Int = 0
    private var cooldownTimer: Timer?
    
    // ── Eye state tracking ──
    private var leftEyeClosedSince: Date? = nil
    private var rightEyeClosedSince: Date? = nil
    private var bothEyesClosedSince: Date? = nil
    private var lastLeftEAR: CGFloat = 1.0
    
    // ── Hand Gesture State ──
    private var lastHandPosition: CGPoint?
    private var lastHandTime: Date?
    private var isPinching: Bool = false
    
    // ── Calibration Visualization ──
    @Published var visibleLeftEAR: Double = 0.3
    @Published var visibleRightEAR: Double = 0.3
    @Published var visibleIsLeftClosed: Bool = false
    @Published var visibleIsRightClosed: Bool = false
    private var lastRightEAR: CGFloat = 1.0
    
    // ── EAR baseline (calibrated per-user) ──
    private var earCalibrationFrames: Int = 0
    private let earCalibrationTarget = 30
    private var earCalibrationSum: CGFloat = 0
    private var earBaseline: CGFloat = 0.28  // default, will be calibrated
    
    // ── Callback ──
    var onGesture: ((FaceGesture) -> Void)?
    
    private var cancellables = Set<AnyCancellable>()
    
    private override init() {
        super.init()
        // ZERO PERMISSION ARCHITECTURE:
        // Do NOT request permissions here.
        // Permissions are requested ONLY when user explicitly enables the feature.
    }
    
    // ════════════════════════════════════════
    // MARK: - Start / Stop
    // ════════════════════════════════════════
    
    func activate() {
        guard isEnabled, !isActive else { return }
        
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    NSLog("👁️ GestureEye: Permission granted. Activating...")
                    DispatchQueue.main.async { self?.activate() }
                } else {
                    NSLog("👁️ GestureEye: Permission denied.")
                }
            }
            return
        }
        
        guard status == .authorized else {
            NSLog("👁️ GestureEye: Cannot activate — camera not authorized (%d)", status.rawValue)
            return
        }
        
        startCapture()
    }
    
    func deactivate() {
        captureSession?.stopRunning()
        captureSession = nil
        videoOutput = nil
        cooldownTimer?.invalidate()
        cooldownTimer = nil
        
        DispatchQueue.main.async {
            self.isActive = false
            self.faceDetected = false
            self.lastGesture = .none
            self.calibrationProgress = 0
            self.isCalibrated = false
            self.cooldownRemaining = 0
            self.faceConfidence = 0
        }
        
        // Reset state
        frameCount = 0
        consecutiveNoFaceFrames = 0
        earCalibrationFrames = 0
        earCalibrationSum = 0
        leftEyeClosedSince = nil
        rightEyeClosedSince = nil
        bothEyesClosedSince = nil
    }
    
    private func startCapture() {
        let session = AVCaptureSession()
        session.sessionPreset = .low
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                ?? AVCaptureDevice.default(for: .video) else {
            NSLog("👁️ GestureEye: ❌ No camera found")
            return
        }
        
        NSLog("👁️ GestureEye: Found camera: %@", device.localizedName)
        
        do {
            try device.lockForConfiguration()
            device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 15)
            device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 15)
            device.unlockForConfiguration()
        } catch {
            NSLog("👁️ GestureEye: ⚠️ Could not set framerate: %@", error.localizedDescription)
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else { return }
            session.addInput(input)
        } catch {
            NSLog("👁️ GestureEye: ❌ Camera input error: %@", error.localizedDescription)
            return
        }
        
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: processingQueue)
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        
        self.captureSession = session
        self.videoOutput = output
        
        processingQueue.async {
            session.startRunning()
            NSLog("👁️ GestureEye: ✅ Capture session running (eye tracking mode)")
        }
        
        DispatchQueue.main.async {
            self.isActive = true
            self.lastFaceSeenTime = Date()
        }
    }
    
    // ════════════════════════════════════════
    // MARK: - Eye Aspect Ratio (EAR)
    // ════════════════════════════════════════
    
    /// Compute Eye Aspect Ratio from Vision eye landmark points
    /// Vision gives 8 points per eye in counterclockwise order:
    /// Points go around the eye contour. We measure height/width ratio.
    private func computeEAR(from points: [CGPoint]) -> CGFloat {
        guard points.count >= 6 else { return 1.0 }
        
        let n = points.count
        
        // For Vision eye landmarks (8 points, counterclockwise from inner corner):
        // Horizontal: distance between point 0 (inner) and point n/2 (outer)
        let innerCorner = points[0]
        let outerCorner = points[n / 2]
        let horizontalDist = hypot(outerCorner.x - innerCorner.x, outerCorner.y - innerCorner.y)
        
        guard horizontalDist > 0.0001 else { return 1.0 }
        
        // Vertical: average of distances between upper and lower lid points
        // Upper lid: points 1...(n/2 - 1)
        // Lower lid: points (n/2 + 1)...(n - 1), reversed
        var verticalSum: CGFloat = 0
        var verticalCount: Int = 0
        
        let upperCount = n / 2 - 1  // number of upper lid points (excluding corners)
        
        for i in 1...upperCount {
            let upperPoint = points[i]
            let lowerIdx = n - i  // corresponding lower lid point
            guard lowerIdx < n else { continue }
            let lowerPoint = points[lowerIdx]
            
            let vDist = hypot(upperPoint.x - lowerPoint.x, upperPoint.y - lowerPoint.y)
            verticalSum += vDist
            verticalCount += 1
        }
        
        guard verticalCount > 0 else { return 1.0 }
        
        let avgVertical = verticalSum / CGFloat(verticalCount)
        return avgVertical / horizontalDist
    }
    
    // ════════════════════════════════════════
    // MARK: - Eye Gesture Detection
    // ════════════════════════════════════════
    
    private func processEyes(_ observation: VNFaceObservation) {
        let now = Date()
        
        guard let landmarks = observation.landmarks,
              let leftEye = landmarks.leftEye,
              let rightEye = landmarks.rightEye else { return }
        
        // Get normalized points
        let leftPoints = leftEye.normalizedPoints
        let rightPoints = rightEye.normalizedPoints
        
        let leftEAR = computeEAR(from: leftPoints)
        let rightEAR = computeEAR(from: rightPoints)
        
        lastLeftEAR = leftEAR
        lastRightEAR = rightEAR
        
        // Debug: log raw points on first frame
        if frameCount == 35 {
            NSLog("👁️ GestureEye: Left eye %d points: %@", leftPoints.count,
                  leftPoints.map { String(format: "(%.3f,%.3f)", $0.x, $0.y) }.joined(separator: " "))
            NSLog("👁️ GestureEye: Right eye %d points: %@", rightPoints.count,
                  rightPoints.map { String(format: "(%.3f,%.3f)", $0.x, $0.y) }.joined(separator: " "))
            NSLog("👁️ GestureEye: Computed EAR L=%.4f R=%.4f", leftEAR, rightEAR)
        }
        
        // ── Calibration: learn user's open-eye EAR ──
        if earCalibrationFrames < earCalibrationTarget {
            earCalibrationSum += (leftEAR + rightEAR) / 2.0
            earCalibrationFrames += 1
            
            DispatchQueue.main.async {
                self.calibrationProgress = Double(self.earCalibrationFrames) / Double(self.earCalibrationTarget)
            }
            
            if earCalibrationFrames == earCalibrationTarget {
                earBaseline = earCalibrationSum / CGFloat(earCalibrationTarget)
                DispatchQueue.main.async {
                    self.isCalibrated = true
                    self.calibrationProgress = 1.0
                }
                NSLog("👁️ GestureEye: ✅ EAR calibrated — baseline=%.3f", earBaseline)
            }
            return
        }
        
        // ── Dynamic thresholds based on calibration + sensitivity ──
        let closedThresh = earBaseline * sensitivity.closedRatio
        let openThresh = earBaseline * 0.70    // 70% of baseline = open
        
        let leftClosed = leftEAR < closedThresh
        let rightClosed = rightEAR < closedThresh
        let leftOpen = leftEAR > openThresh
        let rightOpen = rightEAR > openThresh
        
        // Periodic debug logging
        let shouldLog = (frameCount % 90 == 0) && frameCount <= 450
        if shouldLog {
            NSLog("👁️ GestureEye: EAR L=%.3f R=%.3f (baseline=%.3f, closedThresh=%.3f) leftClosed=%d rightClosed=%d",
                  leftEAR, rightEAR, earBaseline, closedThresh,
                  leftClosed ? 1 : 0, rightClosed ? 1 : 0)
        }
        
        // ── Both eyes closed → slow blink (play/pause) ──
        if leftClosed && rightClosed {
            if bothEyesClosedSince == nil {
                bothEyesClosedSince = now
            }
            // Smart Filter: Don't immediately cancel potential winks.
            // A messy wink often looks like a blink for 1-2 frames.
            // leftEyeClosedSince = nil
            // rightEyeClosedSince = nil
            return
        }
        
        // ── Both eyes just opened after being closed ──
        if let closedSince = bothEyesClosedSince, leftOpen && rightOpen {
            let duration = now.timeIntervalSince(closedSince)
            bothEyesClosedSince = nil
            
            if duration >= sensitivity.blinkMin {
                let timeSinceLast = now.timeIntervalSince(lastGestureTime)
                
                // > 1.2s is a Summoning Blink (Kimi)
                if duration > 1.2 {
                    if timeSinceLast >= sensitivity.cooldown {
                        fireGesture(.longBlink)
                        lastGestureTime = now
                    }
                }
                // 0.4s - 1.2s is a Music Control Blink
                else if duration <= slowBlinkMaxDuration {
                    if timeSinceLast >= sensitivity.cooldown {
                        fireGesture(.slowBlink)
                        lastGestureTime = now
                    }
                }
            }
            return
        }
        bothEyesClosedSince = nil  // Reset if not both closed
        
        // Update visible state for UI calibration (throttled)
        if frameCount % 3 == 0 {
            DispatchQueue.main.async {
                self.visibleLeftEAR = leftEAR
                self.visibleRightEAR = rightEAR
                self.visibleIsLeftClosed = leftClosed
                self.visibleIsRightClosed = rightClosed
            }
        }
        
        // ── Right wink: right eye closed, left eye open → next track ──
        if rightClosed && leftOpen {
            if rightEyeClosedSince == nil {
                rightEyeClosedSince = now
            }
            leftEyeClosedSince = nil
        }
        // Right eye just opened after wink
        else if let closedSince = rightEyeClosedSince, rightOpen {
            let duration = now.timeIntervalSince(closedSince)
            rightEyeClosedSince = nil
            
            if duration >= sensitivity.winkMin && duration <= sensitivity.winkMax {
                let timeSinceLast = now.timeIntervalSince(lastGestureTime)
                if timeSinceLast >= sensitivity.cooldown {
                    fireGesture(.rightWink)
                    lastGestureTime = now
                }
            }
        }
        
        // ── Left wink: left eye closed, right eye open → previous track ──
        if leftClosed && rightOpen {
            if leftEyeClosedSince == nil {
                leftEyeClosedSince = now
            }
            rightEyeClosedSince = nil
        }
        // Left eye just opened after wink
        else if let closedSince = leftEyeClosedSince, leftOpen {
            let duration = now.timeIntervalSince(closedSince)
            leftEyeClosedSince = nil
            
            if duration >= sensitivity.winkMin && duration <= sensitivity.winkMax {
                let timeSinceLast = now.timeIntervalSince(lastGestureTime)
                if timeSinceLast >= sensitivity.cooldown {
                    fireGesture(.leftWink)
                    lastGestureTime = now
                }
            }
        }
    }
    
    // ── Hand Tracking (Vision Pro Style) ──
    private func processHands(_ observation: VNHumanHandPoseObservation) {
        // Points are normalized (0,0 bottom-left, 1,1 top-right)
        guard let thumbTip = try? observation.recognizedPoint(.thumbTip),
              let indexTip = try? observation.recognizedPoint(.indexTip),
              let wrist = try? observation.recognizedPoint(.wrist) else { return }
        
        // Only confident points
        guard thumbTip.confidence > 0.3 && indexTip.confidence > 0.3 else { return }
        
        // 1. Pinch Detection (Thumb + Index distance)
        let distance = hypot(thumbTip.location.x - indexTip.location.x, thumbTip.location.y - indexTip.location.y)
        
        // Thresholds: Pinch < 0.04, Release > 0.1
        if distance < 0.04 {
            if !isPinching {
                // Debounce
                let timeSinceLast = Date().timeIntervalSince(lastGestureTime)
                if timeSinceLast > 1.0 {
                    isPinching = true
                    fireGesture(.handPinch) // Play/Pause
                    lastGestureTime = Date()
                }
            }
        } else if distance > 0.08 {
            isPinching = false
        }
        
        // 2. Swipe Detection (Velocity X of Wrist)
        let now = Date()
        let currentPos = wrist.location
        
        if let lastPos = lastHandPosition, let lastTime = lastHandTime {
            let dt = now.timeIntervalSince(lastTime)
            
            // Calculate velocity only if enough time passed (> 50ms) to reduce noise
            if dt > 0.05 {
                let dx = currentPos.x - lastPos.x
                let dy = currentPos.y - lastPos.y // Track vertical movement too
                
                let velX = dx / CGFloat(dt)
                let velY = dy / CGFloat(dt)
                
                // Swipe Thresholds (Refined)
                // 1. Must be fast enough (> 0.7)
                // 2. Must be horizontal (Vel X > 1.5 * Vel Y) -> Avoid diagonal waves
                
                if abs(velX) > 0.7 && abs(velX) > (abs(velY) * 1.5) {
                    let timeSinceLast = now.timeIntervalSince(lastGestureTime)
                    if timeSinceLast > 1.2 { // Increased cooldown to 1.2s to prevent double-swipes
                        if velX > 0 {
                            // Moving Right in Camera view (Mirrored) = Moving Left in Reality?
                            // Let's assume standard mirror behavior:
                            // Hand moves Right on screen -> Swipe Right -> Next
                            fireGesture(.handSwipeRight)
                        } else {
                            fireGesture(.handSwipeLeft)
                        }
                        lastGestureTime = now
                        lastHandPosition = nil
                        return
                    }
                }
                
                lastHandPosition = currentPos
                lastHandTime = now
            }
        } else {
            lastHandPosition = currentPos
            lastHandTime = now
        }
    }
    
    private func fireGesture(_ gesture: FaceGesture) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.lastGesture = gesture
            self.gestureCount += 1
            self.onGesture?(gesture)
            
            // Cooldown countdown
            self.cooldownRemaining = self.sensitivity.cooldown
            self.cooldownTimer?.invalidate()
            self.cooldownTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
                guard let self = self else { timer.invalidate(); return }
                self.cooldownRemaining = max(0, self.cooldownRemaining - 0.1)
                if self.cooldownRemaining <= 0 { timer.invalidate() }
            }
            
            // Visual flash
            withAnimation(.easeOut(duration: 0.15)) {
                self.gestureFlash = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeOut(duration: 0.3)) {
                    self.gestureFlash = false
                    self.lastGesture = .none
                }
            }
            
            NSLog("👁️ GestureEye: 🎯 Fired %@", gesture.rawValue)
        }
    }
}

// ════════════════════════════════════════
// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
// ════════════════════════════════════════

extension GestureEyeEngine: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        frameCount += 1
        
        // 1. Face Request
        let faceRequest = VNDetectFaceLandmarksRequest { [weak self] request, error in
            guard let self = self else { return }
            if error != nil { return }
            
            if let faces = request.results as? [VNFaceObservation], let face = faces.first {
                DispatchQueue.main.async {
                    if !self.faceDetected {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            self.faceDetected = true
                        }
                    }
                }
                self.lastFaceSeenTime = Date()
                self.consecutiveNoFaceFrames = 0
                
                // Process eyes for gesture detection
                self.processEyes(face)
            } else {
                self.consecutiveNoFaceFrames += 1
                
                if self.consecutiveNoFaceFrames > 45 {
                    DispatchQueue.main.async {
                        if self.faceDetected {
                            withAnimation(.easeInOut(duration: 1.0)) {
                                self.faceDetected = false
                            }
                        }
                    }
                }
                
                let timeSinceLastFace = Date().timeIntervalSince(self.lastFaceSeenTime)
                if timeSinceLastFace > self.noFaceTimeout {
                    DispatchQueue.main.async {
                        self.deactivate()
                        NSLog("👁️ GestureEye: Auto-deactivated (no face for 30s)")
                    }
                }
            }
        }
        
        // 2. Hand Request (New!)
        let handRequest = VNDetectHumanHandPoseRequest()
        handRequest.maximumHandCount = 1
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .leftMirrored, options: [:])
        
        do {
            // Perform both requests in parallel
            try handler.perform([faceRequest, handRequest])
            
            // 3. Process Hands
            if let handObservation = handRequest.results?.first {
                self.processHands(handObservation)
            }
        } catch {
            // Ignore frame drop errors
        }
    }
}
