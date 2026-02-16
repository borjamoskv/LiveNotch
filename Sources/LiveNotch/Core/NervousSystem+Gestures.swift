import SwiftUI
import Combine
import os

private let gestureLog = NotchLog.make("GestureEye")

// ═══════════════════════════════════════════════════
// MARK: - 👁️ GestureEye Integration
// ═══════════════════════════════════════════════════

extension NervousSystem {
    
    /// Wire up GestureEye callbacks
    func setupGestureEye() {
        let engine = GestureEyeEngine.shared
        
        engine.onGesture = { [weak self] gesture in
            self?.handleFaceGesture(gesture)
        }
        
        // Bind published state
        engine.$isActive
            .receive(on: DispatchQueue.main)
            .assign(to: &$gestureEyeActive)
        
        engine.$faceDetected
            .receive(on: DispatchQueue.main)
            .assign(to: &$gestureEyeFaceDetected)
        
        engine.$lastGesture
            .receive(on: DispatchQueue.main)
            .assign(to: &$gestureEyeLastGesture)
        
        // Activate immediately — camera permission is requested at init
        // The engine handles auth status internally
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            engine.activate()
        }
    }
    
    /// Re-activate GestureEye when music starts (in case it auto-deactivated)
    func handleMusicStateChange(isPlaying: Bool) {
        if isPlaying && !GestureEyeEngine.shared.isActive && GestureEyeEngine.shared.isEnabled {
            GestureEyeEngine.shared.activate()
        }
    }
    
    /// Handle detected face gesture → context-aware action
    func handleFaceGesture(_ gesture: FaceGesture) {
        #if DEBUG
        gestureLog.debug("👁️ GestureEye: handleFaceGesture → \(gesture.rawValue)")
        #endif
        
        // Publish to UI for feedback
        DispatchQueue.main.async { [weak self] in
            self?.lastDetectedGesture = gesture
        }
        
        // ── Context-aware: music mode vs AI mode ──
        if isPlayingMusic {
            // 🎵 Music mode — control playback
            switch gesture {
            case .rightWink, .handSwipeRight:
                runAppleScript("tell application \"Spotify\" to next track")
            case .leftWink, .handSwipeLeft:
                runAppleScript("tell application \"Spotify\" to previous track")
            case .slowBlink, .handPinch:
                runAppleScript("tell application \"Spotify\" to playpause")
            case .longBlink:
                 // ❤️ Long blink to love track
                runAppleScript("tell application \"Spotify\" to set loved of current track to true")
                HapticManager.shared.play(.success)
                
            case .none:
                break
            }
        } else {
            // 🧠 AI mode — interact with Kimi
            switch gesture {
            case .slowBlink, .handPinch:
                // Toggle AI bar
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: .gestureToggleAI, object: nil
                    )
                }
                
            case .rightWink:
                // "¿Qué tengo en el clipboard?" → send to Kimi
                DispatchQueue.main.async {
                    let clip = NSPasteboard.general.string(forType: .string) ?? ""
                    guard !clip.isEmpty else { return }
                    NotificationCenter.default.post(
                        name: .gestureClipboardAI, object: clip
                    )
                }
                
            case .leftWink:
                // Quick action: expand/collapse notch
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: .gestureToggleNotch, object: nil
                    )
                }
                
            case .longBlink:
                // 🧠 Summon Notch Brain (Proprietary AI)
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: .gestureSummonBrain, object: nil
                    )
                    HapticManager.shared.play(.heavy) // Heartbeat start
                }

            case .handSwipeLeft, .handSwipeRight:
                break // No specific AI action for hand swipes yet
                
            case .none:
                break
            }
        }
    }
    
    /// Run AppleScript asynchronously
    private func runAppleScript(_ source: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            #if DEBUG
            gestureLog.debug("👁️ GestureEye: Running AppleScript: \(source)")
            #endif
            
            if let script = NSAppleScript(source: source) {
                var error: NSDictionary?
                script.executeAndReturnError(&error)
                if let error = error {
                    gestureLog.error("👁️ GestureEye: ❌ AppleScript error: \(error)")
                } else {
                    #if DEBUG
                    gestureLog.debug("👁️ GestureEye: ✅ AppleScript executed OK")
                    #endif
                }
            } else {
                gestureLog.error("👁️ GestureEye: ❌ Could not create NSAppleScript")
            }
        }
    }
}
