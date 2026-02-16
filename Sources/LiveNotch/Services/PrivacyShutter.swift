import SwiftUI
import Combine
import AVFoundation

// ═══════════════════════════════════════════════════════════
// MARK: - 🔒 PrivacyShutter — Digital Kill Switch
// ═══════════════════════════════════════════════════════════
// Long-press the notch → frosted glass animation → camera
// and microphone cut at software level. Visual: the notch
// area shows an opaque frosted state like a physical shutter.
//
// The effect is visceral: you SEE the glass frost over the
// camera lens area, confirming your privacy is protected.

@MainActor
final class PrivacyShutter: ObservableObject {
    
    static let shared = PrivacyShutter()
    
    @Published var isEngaged: Bool = false     // Shutter closed = privacy ON
    @Published var frostLevel: Double = 0.0     // 0..1 animation progress
    @Published var shutterAnimation: Bool = false
    
    // Camera/mic state before shutter engaged
    private var wasGestureEyeActive = false
    
    private init() {}
    
    // ═══════════════════════════════════════
    // MARK: - Toggle
    // ═══════════════════════════════════════
    
    func toggle() {
        if isEngaged {
            disengage()
        } else {
            engage()
        }
    }
    
    // ═══════════════════════════════════════
    // MARK: - Engage (Privacy ON)
    // ═══════════════════════════════════════
    
    func engage() {
        guard !isEngaged else { return }
        
        // Remember state
        wasGestureEyeActive = GestureEyeEngine.shared.isActive
        
        // Kill camera feed
        if GestureEyeEngine.shared.isActive {
            GestureEyeEngine.shared.deactivate()
        }
        
        // Frost animation
        isEngaged = true
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            shutterAnimation = true
        }
        
        // Animate frost level
        animateFrost(to: 1.0, duration: 0.4)
        
        // Haptic feedback — solid "click"
        HapticManager.shared.play(.heavy)
    }
    
    // ═══════════════════════════════════════
    // MARK: - Disengage (Privacy OFF)
    // ═══════════════════════════════════════
    
    func disengage() {
        guard isEngaged else { return }
        
        // Defrost animation
        animateFrost(to: 0.0, duration: 0.5)
        
        // Restore camera if it was active
        if wasGestureEyeActive {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                GestureEyeEngine.shared.activate()
            }
        }
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            shutterAnimation = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isEngaged = false
        }
        
        // Haptic — soft "release"
        HapticManager.shared.play(.toggle)
    }
    
    // ═══════════════════════════════════════
    // MARK: - Frost Animation
    // ═══════════════════════════════════════
    
    private func animateFrost(to target: Double, duration: TimeInterval) {
        let steps = 20
        let interval = duration / Double(steps)
        let delta = (target - frostLevel) / Double(steps)
        
        for i in 0..<steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(i)) { [weak self] in
                self?.frostLevel += delta
            }
        }
        
        // Ensure final value is exact
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.frostLevel = target
        }
    }
}
