import SwiftUI

// ═══════════════════════════════════════════════════
// MARK: - Themes & Features
// ═══════════════════════════════════════════════════

extension UserMode {
    
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
