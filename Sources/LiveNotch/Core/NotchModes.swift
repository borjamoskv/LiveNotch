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
    
    // ── Theme System ──
    struct ModeTheme {
        let gradient: LinearGradient
        let mainColor: Color
        let glowIntensity: Double
        let borderOpacity: Double
    }
    
    var theme: ModeTheme {
        switch self {
        case .normal:
            return ModeTheme(
                gradient: LinearGradient(colors: [.white, .cyan.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing),
                mainColor: .cyan,
                glowIntensity: 0.8,
                borderOpacity: 0.4
            )
        case .tdah:
            return ModeTheme(
                gradient: LinearGradient(colors: [.cyan, .mint], startPoint: .top, endPoint: .bottom),
                mainColor: .cyan,
                glowIntensity: 0.5,
                borderOpacity: 0.25
            )
        case .focus:
            return ModeTheme(
                gradient: LinearGradient(colors: [Color(red: 0.0, green: 0.8, blue: 0.4), .teal], startPoint: .topLeading, endPoint: .bottomTrailing),
                mainColor: Color(red: 0.0, green: 0.8, blue: 0.4),
                glowIntensity: 0.6,
                borderOpacity: 0.3
            )
        case .dj:
            return ModeTheme(
                gradient: LinearGradient(colors: [.pink, .purple, .orange], startPoint: .leading, endPoint: .trailing),
                mainColor: .pink,
                glowIntensity: 1.2, // High energy
                borderOpacity: 0.8
            )
        case .producer:
            return ModeTheme(
                gradient: LinearGradient(colors: [.orange, .red], startPoint: .top, endPoint: .bottom),
                mainColor: .orange,
                glowIntensity: 0.9,
                borderOpacity: 0.6
            )
        case .creative:
            return ModeTheme(
                gradient: LinearGradient(colors: [.purple, .blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing),
                mainColor: .purple,
                glowIntensity: 0.9,
                borderOpacity: 0.5
            )
        case .images:
            return ModeTheme(
                gradient: LinearGradient(colors: [.gray, .white], startPoint: .top, endPoint: .bottom),
                mainColor: .gray,
                glowIntensity: 0.5, // Neutral but visible
                borderOpacity: 0.3
            )
        case .gaming:
            return ModeTheme(
                gradient: LinearGradient(colors: [.green, .mint, .cyan], startPoint: .top, endPoint: .bottom),
                mainColor: .green,
                glowIntensity: 1.1,
                borderOpacity: 0.7
            )
        case .night:
            return ModeTheme(
                gradient: LinearGradient(colors: [.orange, .brown], startPoint: .top, endPoint: .bottom),
                mainColor: .orange,
                glowIntensity: 0.3, // Warm & Dim
                borderOpacity: 0.15
            )
        case .presentation:
            return ModeTheme(
                gradient: LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing),
                mainColor: .blue,
                glowIntensity: 0.2, // Static
                borderOpacity: 0.1
            )
        case .psionic:
            return ModeTheme(
                gradient: LinearGradient(colors: [Color(hex: "8A2BE2"), Color(hex: "00FFFF"), Color(hex: "FF00FF")], startPoint: .topLeading, endPoint: .bottomTrailing),
                mainColor: Color(hex: "8A2BE2"),
                glowIntensity: 2.0, // GOD MODE MAX - Blinding light
                borderOpacity: 1.0
            )
        case .daemon:
            return ModeTheme(
                gradient: LinearGradient(colors: [.gray, .white.opacity(0.6)], startPoint: .top, endPoint: .bottom),
                mainColor: .gray,
                glowIntensity: 0.4,
                borderOpacity: 0.2
            )
        }
    }
    
    var blurMaterial: Material {
        switch self {
        case .normal:       return .regular
        case .tdah:         return .ultraThin
        case .focus:        return .ultraThin
        case .dj:           return .thick
        case .producer:     return .thick
        case .creative:     return .bar
        case .images:       return .ultraThin
        case .gaming:       return .thick
        case .night:        return .ultraThin
        case .presentation: return .regular
        case .daemon:       return .ultraThin
        case .psionic:      return .ultraThin
        }
    }
    
    // Legacy support (computed from theme)
    var tint: Color { theme.mainColor }
    
    /// Features shown in the notch when this mode is active
    var activeFeatures: [ModeFeature] {
        switch self {
        case .normal:       return [.music, .battery, .clock, .notifications, .network]
        case .tdah:         return [.timer, .clock, .battery]
        case .focus:        return [.timer, .clock, .notes]
        case .dj:           return [.music, .audioViz, .lyrics, .bpm]
        case .producer:     return [.cpu, .ram, .disk, .audioLatency, .midi, .network]
        case .creative:     return [.music, .notes, .battery, .clock]
        case .images:       return [.colorPicker, .fileShelf, .clock]
        case .gaming:       return [.clock, .battery, .cpu, .network]
        case .night:        return [.clock, .battery]
        case .presentation: return [.clock, .battery]
        case .daemon:       return [.clock] // Minimal, eyes take over
        case .psionic:      return ModeFeature.allCases // ALL CAPABILITIES
        }
    }
}

// ═══════════════════════════════════════════════════
// MARK: - Mode Features
// ═══════════════════════════════════════════════════

enum ModeFeature: String, CaseIterable {
    case music        = "music"
    case audioViz     = "audioViz"
    case lyrics       = "lyrics"
    case bpm          = "bpm"
    case timer        = "timer"
    case clock        = "clock"
    case battery      = "battery"
    case cpu          = "cpu"
    case ram          = "ram"
    case disk         = "disk"
    case audioLatency = "audioLatency"
    case midi         = "midi"
    case notifications = "notifications"
    case notes        = "notes"
    case colorPicker  = "colorPicker"
    case fileShelf    = "fileShelf"
    case network      = "network"
}
