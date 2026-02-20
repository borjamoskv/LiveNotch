import SwiftUI
import Combine

// ═══════════════════════════════════════════════════
// MARK: - 🎛️ User Mode System
// ═══════════════════════════════════════════════════
// Each mode adjusts behavior, visuals, and notifications.
// 10 modes covering every use case:
//   Normal, TDAH, Focus, DJ, Producer, Creative, Images, Gaming, Night, Presentation

@MainActor
final class UserModeManager: ObservableObject {
    static let shared = UserModeManager()
    private let log = NotchLog.make("UserModeManager")
    
    @Published var activeMode: UserMode = .normal {
        didSet {
            if oldValue != activeMode {
                applyMode(activeMode)
                HapticManager.shared.play(.toggle)
                log.info("Mode changed: \(oldValue.rawValue) → \(activeMode.rawValue)")
            }
        }
    }
    
    @Published var previousMode: UserMode = .normal
    
    private init() {}
    
    // ── Apply mode effects ──
    private func applyMode(_ mode: UserMode) {
        let nervous = NervousSystem.shared
        
        switch mode {
        case .tdah:
            // TDAH/ADHD Mode:
            // - Minimal visual noise, calmer animations
            // - Block distracting notifications
            // - Enable focus timer automatically
            // - Muted color palette, reduced breathing
            nervous.breathIntensity = 0.03
            nervous.chameleonEnabled = false
            GestureEyeEngine.shared.sensitivity = .relaxed
            
        case .focus:
            // Deep Focus Mode:
            // - Zero distractions, DND activated
            // - Pomodoro auto-starts
            // - Only timer + clock visible
            // - No music controls (intentional silence)
            nervous.breathIntensity = 0.01
            nervous.chameleonEnabled = false
            GestureEyeEngine.shared.isEnabled = false
            // MARK: - [Deferred] Focus management via NSFocusManager (Phase 2)
            
        case .dj:
            // DJ Mode:
            // - Full audio visualization (BPM, waveform, spectrum)
            // - Enhanced music controls (deck A/B, crossfader feel)
            // - Live lyrics prominent
            // - Beat-reactive breathing (max intensity)
            // - BPM counter displayed
            nervous.breathIntensity = 0.20
            nervous.chameleonEnabled = true
            // AudioPulseEngine gets priority rendering
            
        case .producer:
            // Producer Mode:
            // - CPU/RAM/Disk monitor (FL Studio/Ableton awareness)
            // - Audio I/O latency display
            // - MIDI activity indicator
            // - Moderate breathing, muted tones
            // - SystemForge integration: disk space warnings
            nervous.breathIntensity = 0.06
            nervous.chameleonEnabled = false
            // NetworkSpeedMonitor shows audio stream stats
            
        case .creative:
            // Creative/Flow Mode:
            // - Enhanced music reactivity
            // - Vibrant colors, full animation range
            // - Inspiration widgets active
            nervous.breathIntensity = 0.12
            nervous.chameleonEnabled = true
            
        case .images:
            // Images/Visual Art Mode:
            // - Color picker from screen active
            // - Clean UI for visual reference
            // - Neutral notch (no tint interference with colors)
            // - Quick screenshot shelf
            // - Naroa/portfolio integration
            nervous.breathIntensity = 0.04
            nervous.chameleonEnabled = false
            // Neutral background so it doesn't bias color perception
            
        case .gaming:
            // Gaming Mode:
            // - Minimal UI footprint
            // - Performance priority (reduce all rendering)
            // - Only essential info (time, battery, fps)
            nervous.breathIntensity = 0.05
            nervous.chameleonEnabled = false
            
        case .night:
            // Night/Sleep Mode:
            // - Dim everything, warm tones only
            // - Minimal brightness
            // - No audio alerts, no haptics
            nervous.breathIntensity = 0.02
            nervous.chameleonEnabled = false
            
        case .presentation:
            // Presentation Mode:
            // - Clean, professional appearance
            // - No notifications, no breathing
            // - Static, neutral colors
            nervous.breathIntensity = 0.0
            nervous.chameleonEnabled = false
            GestureEyeEngine.shared.isEnabled = false
            
        case .psionic:
            // 👁️ GOD MODE (Psionic):
            // - "More vitamins and drugs" requested.
            // - Max intensity breathing (hyperventilating UI)
            // - Full sensor fusion + glitch effects
            // - All features active
            nervous.breathIntensity = 0.30
            nervous.chameleonEnabled = true
            GestureEyeEngine.shared.sensitivity = .sensitive
            // Future: Trigger glitch shaders here
            
        case .normal:
            // Default — restore standard behavior
            nervous.breathIntensity = 0.07
            nervous.chameleonEnabled = true
            
        case .daemon:
            // Daemon Mode: Background shadow — minimal and aware
            nervous.breathIntensity = 0.05
            nervous.chameleonEnabled = true
        }
    }
    
    // ── Quick toggle: enter/exit a mode ──
    func toggle(_ mode: UserMode) {
        if activeMode == mode {
            activeMode = .normal
        } else {
            previousMode = activeMode
            activeMode = mode
        }
    }
    
    // ── Cycle through modes (Skip Psionic) ──
    func cycleNext() {
        let all = UserMode.allCases.filter { $0 != .psionic }
        guard let idx = all.firstIndex(of: activeMode) else { 
            activeMode = .normal
            return 
        }
        let next = all.index(after: idx)
        activeMode = next < all.endIndex ? all[next] : all[all.startIndex]
    }
}

// ═══════════════════════════════════════════════════
// MARK: - Mode Definitions (11 Modes)
// ═══════════════════════════════════════════════════

enum UserMode: String, CaseIterable, Identifiable, Codable {
    case normal       = "Normal"
    case tdah         = "TDAH"
    case focus        = "Focus"
    case dj           = "DJ"
    case producer     = "Producer"
    case creative     = "Creative"
    case images       = "Images"
    case gaming       = "Gaming"
    case night        = "Night"
    case presentation = "Presentation"
    case daemon       = "Daemon" // 👻 New
    case psionic      = "Psionic"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .normal:       return "circle.grid.2x2"
        case .tdah:         return "brain.head.profile"
        case .focus:        return "target"
        case .dj:           return "headphones"
        case .producer:     return "tuningfork"
        case .creative:     return "paintbrush.pointed.fill"
        case .images:       return "photo.artframe"
        case .gaming:       return "gamecontroller.fill"
        case .night:        return "moon.fill"
        case .presentation: return "play.rectangle.fill"
        case .daemon:       return "eye.fill"
        case .psionic:      return "eye.trianglebadge.exclamationmark"
        }
    }
    
    var label: String {
        switch self {
        case .normal:       return "Normal"
        case .tdah:         return "TDAH"
        case .focus:        return "Focus"
        case .dj:           return "DJ"
        case .producer:     return "Producer"
        case .creative:     return "Creative"
        case .images:       return "Images"
        case .gaming:       return "Gaming"
        case .night:        return "Night"
        case .presentation: return "Present"
        case .daemon:       return "Daemon"
        case .psionic:      return "GOD MODE"
        }
    }
    
    var subtitle: String {
        switch self {
        case .normal:       return "Standard mode"
        case .tdah:         return "Reduce distractions"
        case .focus:        return "Deep work, zero noise"
        case .dj:           return "Audio visual, BPM, lyrics"
        case .producer:     return "CPU, latency, MIDI"
        case .creative:     return "Full immersion"
        case .images:       return "Neutral, color picker"
        case .gaming:       return "Minimal UI"
        case .night:        return "Easy on eyes"
        case .presentation: return "Clean & static"
        case .daemon:       return "Tu Sombra Digital"
        case .psionic:      return "Reality Overflow"
        }
    }
    
}
