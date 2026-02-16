import SwiftUI

// ═══════════════════════════════════════════════════
// MARK: - 🎨 Notch Theme Engine — 6 Design Languages
// ═══════════════════════════════════════════════════
// Each theme defines a complete visual language:
// accent color, border style, visualizer, typography, glow

enum NotchTheme: String, CaseIterable, Identifiable {
    case txalaparta   // Pill negra mate + minimal visualizer
    case basqueSteel  // Monocromo total, inner shadow, ultra-clean
    case neonHarbor   // Imperceptible gradient by mode
    case tapeDeck     // Hardware transport icons, mini VU
    case glitchMercy  // Glitch as EVENT only
    case loreTotem    // Project sigil center, hover → chapters
    
    var id: String { rawValue }
    
    // ═══════════════════════════════════════
    // MARK: - Display
    // ═══════════════════════════════════════
    
    var displayName: String {
        switch self {
        case .txalaparta: return "Txalaparta Pulse"
        case .basqueSteel: return "Basque Steel"
        case .neonHarbor: return "Neon Harbor"
        case .tapeDeck: return "Tape Deck"
        case .glitchMercy: return "Glitch Mercy"
        case .loreTotem: return "Lore Totem"
        }
    }
    
    var subtitle: String {
        switch self {
        case .txalaparta: return "Minimal percussion pulse"
        case .basqueSteel: return "Monocromo perfection"
        case .neonHarbor: return "Subtle reactive gradient"
        case .tapeDeck: return "Analog hardware feel"
        case .glitchMercy: return "Glitch as sacred event"
        case .loreTotem: return "Storytelling UI"
        }
    }
    
    var icon: String {
        switch self {
        case .txalaparta: return "waveform.path"
        case .basqueSteel: return "rectangle.inset.filled"
        case .neonHarbor: return "water.waves"
        case .tapeDeck: return "recordingtape"
        case .glitchMercy: return "bolt.trianglebadge.exclamationmark"
        case .loreTotem: return "shield.lefthalf.filled"
        }
    }
    
    // ═══════════════════════════════════════
    // MARK: - Colors
    // ═══════════════════════════════════════
    
    var accentColor: Color {
        switch self {
        case .txalaparta: return Color(red: 0.2, green: 0.9, blue: 0.3)   // Acid green
        case .basqueSteel: return Color.white.opacity(0.6)                  // Pure mono
        case .neonHarbor: return Color(red: 0.4, green: 0.7, blue: 0.9)   // Soft cyan
        case .tapeDeck: return Color(red: 0.9, green: 0.6, blue: 0.2)     // Warm amber
        case .glitchMercy: return Color(red: 1.0, green: 0.2, blue: 0.4)  // Signal red
        case .loreTotem: return Color(red: 0.7, green: 0.5, blue: 1.0)    // Mystic purple
        }
    }
    
    var borderColor: Color {
        switch self {
        case .txalaparta: return accentColor.opacity(0.15)
        case .basqueSteel: return Color.white.opacity(0.06)
        case .neonHarbor: return accentColor.opacity(0.08)
        case .tapeDeck: return accentColor.opacity(0.12)
        case .glitchMercy: return Color.white.opacity(0.04)  // No border until event
        case .loreTotem: return accentColor.opacity(0.1)
        }
    }
    
    // ═══════════════════════════════════════
    // MARK: - Border
    // ═══════════════════════════════════════
    
    var borderWidth: CGFloat {
        switch self {
        case .txalaparta: return 1.0   // Acid green 1px
        case .basqueSteel: return 0.0  // Inner shadow only
        case .neonHarbor: return 0.5
        case .tapeDeck: return 0.8
        case .glitchMercy: return 0.0  // Only on events
        case .loreTotem: return 0.5
        }
    }
    
    var innerShadow: Bool {
        self == .basqueSteel
    }
    
    // ═══════════════════════════════════════
    // MARK: - Visualizer
    // ═══════════════════════════════════════
    
    var visualizerStyle: VisualizerStyle {
        switch self {
        case .txalaparta: return .minimalBars(count: 5)
        case .basqueSteel: return .none
        case .neonHarbor: return .gradientPulse
        case .tapeDeck: return .vuMeter
        case .glitchMercy: return .none  // Only on events
        case .loreTotem: return .none    // Sigil only
        }
    }
    
    var showVisualizerOnlyWhenPlaying: Bool {
        switch self {
        case .txalaparta: return true   // Key feature: only when audio
        case .tapeDeck: return true     // VU only with audio
        default: return false
        }
    }
    
    // ═══════════════════════════════════════
    // MARK: - Typography
    // ═══════════════════════════════════════
    
    var fontWeight: Font.Weight {
        switch self {
        case .basqueSteel: return .ultraLight
        case .tapeDeck: return .medium
        default: return .regular
        }
    }
    
    var letterSpacing: CGFloat {
        switch self {
        case .basqueSteel: return 1.5  // Ultra clean spacing
        case .loreTotem: return 0.8
        default: return 0.0
        }
    }
    
    // ═══════════════════════════════════════
    // MARK: - Glow
    // ═══════════════════════════════════════
    
    var glowIntensity: CGFloat {
        switch self {
        case .txalaparta: return 0.0   // No glow
        case .basqueSteel: return 0.0  // Pure
        case .neonHarbor: return 0.15  // Subtle
        case .tapeDeck: return 0.1     // Warm
        case .glitchMercy: return 0.0  // Event-only
        case .loreTotem: return 0.2    // Mystic
        }
    }
    
    var glowColor: Color {
        accentColor.opacity(glowIntensity)
    }
}

// ═══════════════════════════════════════════════════
// MARK: - Visualizer Style
// ═══════════════════════════════════════════════════

enum VisualizerStyle {
    case none
    case minimalBars(count: Int)
    case gradientPulse
    case vuMeter
}

// ═══════════════════════════════════════════════════
// MARK: - 🎛️ Theme Engine — Runtime Manager
// ═══════════════════════════════════════════════════

@MainActor
final class ThemeEngine: ObservableObject {
    static let shared = ThemeEngine()
    
    @Published var activeTheme: NotchTheme {
        didSet {
            UserDefaults.standard.set(activeTheme.rawValue, forKey: "notchTheme")
        }
    }
    
    private init() {
        let saved = UserDefaults.standard.string(forKey: "notchTheme") ?? "txalaparta"
        self.activeTheme = NotchTheme(rawValue: saved) ?? .txalaparta
    }
    
    func cycle() {
        let all = NotchTheme.allCases
        guard let idx = all.firstIndex(of: activeTheme) else { return }
        activeTheme = all[(idx + 1) % all.count]
    }
}
