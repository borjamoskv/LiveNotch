import SwiftUI
import AppKit

extension NervousSystem {
    
    // ════════════════════════════════════════
    // MARK: - Emotional Mirror (Anxiety, Energy, Flow)
    // ════════════════════════════════════════
    
    /// Evaluate the user's emotional state based on system telemetry.
    /// This is the "Soul" of the notch, reflecting the user's rhythm.
    func evaluateEmotionalState() {
        let now = Date()
        
        // ── 1. Anxiety: app switches in last 60s ──
        let switchRate = recentAppSwitchRate()
        let targetAnxiety = min(Double(switchRate) / 10.0, 1.0)  // 10+ switches/min = max anxiety
        
        withAnimation(.easeInOut(duration: 3.0)) {
            // Smooth towards target (don't snap)
            anxietyLevel = anxietyLevel * 0.7 + targetAnxiety * 0.3
        }
        
        // ── 2. Energy: based on time of day (circadian rhythm) ──
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let hourDecimal = Double(hour) + Double(minute) / 60.0
        
        var targetEnergy: Double = 0.5
        switch hour {
        case 5..<9:    targetEnergy = 0.3 + (hourDecimal - 5) * 0.1   // Waking up
        case 9..<12:   targetEnergy = 0.7 + (hourDecimal - 9) * 0.1   // Morning peak
        case 12..<14:  targetEnergy = 0.8 - (hourDecimal - 12) * 0.1  // Post-lunch dip
        case 14..<17:  targetEnergy = 0.6 + (hourDecimal - 14) * 0.1  // Afternoon rally
        case 17..<21:  targetEnergy = 0.6 - (hourDecimal - 17) * 0.08 // Evening decline
        case 21..<24:  targetEnergy = max(0.15, 0.3 - (hourDecimal - 21) * 0.05)  // Night wind down
        default:       targetEnergy = 0.15  // Late night / early morning
        }
        
        withAnimation(.easeInOut(duration: 5.0)) {
            energyCurve = energyCurve * 0.8 + targetEnergy * 0.2
        }
        
        // ── 3. Flow detection ──
        let wasInFlow = isInFlowState
        // Flow criteria: 
        // - In a coding/creative app
        // - < 2 app switches in last 2 mins
        // - > 5 mins of activity in same app
        let flowApp = Self.codingBundleIDs.contains(activeAppBundleID) || Self.creativeBundleIDs.contains(activeAppBundleID)
        let stableApp = switchRate < 1
        
        if flowApp && stableApp && !isMeetingActive && !isAsleep {
            isInFlowState = true
        } else if switchRate > 4 || isAsleep {
            isInFlowState = false
        }
        
        // ── 4. Sleep/Inactivity ──
        let timeSinceInput = now.timeIntervalSince(lastInputTime)
        if timeSinceInput > 300 && !isAsleep {  // 5 min
            withAnimation(.easeInOut(duration: 4.0)) {
                isAsleep = true
            }
        }
        
        // ── 5. Session duration ──
        sessionMinutes = Int(now.timeIntervalSince(sessionStartTime) / 60)
        
        // ── 6. Compute final ambient glow ──
        computeAmbientGlow()
        
        // Re-evaluate mood with new emotional data
        if !wasInFlow && isInFlowState || wasInFlow && !isInFlowState {
            evaluateMood()
        }
    }
    
    /// Switches per minute in the last 60 seconds
    func recentAppSwitchRate() -> Int {
        let cutoff = Date().addingTimeInterval(-60)
        appSwitchTimestamps.removeAll { $0 < cutoff }
        return appSwitchTimestamps.count
    }
}
