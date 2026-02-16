import AppKit

// ═══════════════════════════════════════════════════
// MARK: - 🔊 Haptic Feedback Manager
// ═══════════════════════════════════════════════════
// Premium haptic engine — every interaction has a physical "feel".
// Dry impacts = Mercedes-door-close: short, seco, sólido.

final class HapticManager {
    static let shared = HapticManager()
    private init() {}
    
    var isEnabled: Bool = NotchPersistence.shared.bool(.hapticEnabled, default: true) {
        didSet { NotchPersistence.shared.set(.hapticEnabled, value: isEnabled) }
    }
    
    enum HapticType {
        // ── Standard Feedback ──
        case success    // Click feedback
        case warning    // Thump feedback
        case error      // Double-thump
        case toggle     // Soft click
        case heavy      // Strong press
        case alignment  // Very subtle
        case subtle     // Generic
        case expand     // Panel expansion
        case collapse   // Panel collapse
        case button     // Button press
        case message    // Incoming notification
        
        // ── Contextual Feedback ──
        case soft       // Gentle nudge — subtle state hint
        case peek       // Quick peep into content — ultralight
        case drop       // File/item drop — satisfying landing
        case scriptLaunch // Script execution start
        case scriptKill   // Script force-killed
        
        // ── Dry Impacts (Premium) ──
        // Ultra-short, no-resonance haptics. Like tapping glass, not rubber.
        case dryTick    // Toggle switches, checkboxes — shortest possible
        case drySnap    // State transitions, mode changes — crisp level-change
        case dryThud    // Expansion complete, drawer arrival — heavy finality
    }
    
    /// Fire haptic immediately.
    func play(_ type: HapticType) {
        guard isEnabled else { return }
        
        let performer = NSHapticFeedbackManager.defaultPerformer
        switch type {
        case .success:
            performer.perform(.generic, performanceTime: .default)
        case .warning:
            performer.perform(.levelChange, performanceTime: .default)
        case .error:
            performer.perform(.levelChange, performanceTime: .default)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                performer.perform(.levelChange, performanceTime: .default)
            }
        case .toggle:
            performer.perform(.generic, performanceTime: .drawCompleted)
        case .heavy:
            performer.perform(.levelChange, performanceTime: .drawCompleted)
        case .alignment:
            performer.perform(.alignment, performanceTime: .drawCompleted)
        case .subtle:
            performer.perform(.generic, performanceTime: .drawCompleted)
        case .expand:
            performer.perform(.levelChange, performanceTime: .default)
        case .collapse:
            performer.perform(.generic, performanceTime: .default)
        case .button:
            performer.perform(.generic, performanceTime: .drawCompleted)
        case .message:
            performer.perform(.levelChange, performanceTime: .default)
            
        // ── Contextual ──
        case .soft:
            performer.perform(.generic, performanceTime: .drawCompleted)
        case .peek:
            performer.perform(.alignment, performanceTime: .drawCompleted)
        case .drop:
            performer.perform(.levelChange, performanceTime: .drawCompleted)
        case .scriptLaunch:
            performer.perform(.generic, performanceTime: .default)
        case .scriptKill:
            performer.perform(.levelChange, performanceTime: .default)
            
        // ── Dry Impacts ──
        // .drawCompleted fires at next frame boundary = tightest sync with animation
        case .dryTick:
            performer.perform(.alignment, performanceTime: .drawCompleted)
        case .drySnap:
            performer.perform(.generic, performanceTime: .drawCompleted)
        case .dryThud:
            performer.perform(.levelChange, performanceTime: .drawCompleted)
        }
    }
    
    /// Fire haptic synchronized with animation keyframe.
    /// Use for ms-precision: haptic fires exactly when animation reaches its target.
    /// - Parameters:
    ///   - type: The haptic type to fire
    ///   - delay: Seconds to wait before firing (align with spring settle time)
    func playSync(_ type: HapticType, delay: TimeInterval) {
        guard isEnabled else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.play(type)
        }
    }
}
