import Foundation

// ═══════════════════════════════════════════════════
// MARK: - 🌍 Localization Helper
// ═══════════════════════════════════════════════════
// Auto-detects system language and provides localized strings.
// Supports: English, Spanish. Extensible.

enum L10n {
    
    // Detect system language once
    static let lang: Language = {
        let code = Locale.current.language.languageCode?.identifier ?? "en"
        switch code {
        case "es": return .es
        case "en": return .en
        default: return .en
        }
    }()
    
    enum Language {
        case en, es
    }
    
    // ── Panel Titles ──
    static var settings: String { lang == .es ? "Ajustes" : "Settings" }
    static var clipboard: String { lang == .es ? "Portapapeles" : "Clipboard" }
    static var fileTray: String { lang == .es ? "Archivos" : "File Tray" }
    static var mindflow: String { lang == .es ? "Mindflow" : "Mindflow" }
    static var volumeMixer: String { lang == .es ? "Mezclador" : "Volume Mixer" }
    static var eyeControl: String { lang == .es ? "Control Ocular" : "Eye Control" }
    
    // ── Settings Sections ──
    static var appearance: String { lang == .es ? "APARIENCIA" : "APPEARANCE" }
    static var behavior: String { lang == .es ? "COMPORTAMIENTO" : "BEHAVIOR" }
    static var aiAssistant: String { lang == .es ? "ASISTENTE IA" : "AI ASSISTANT" }
    
    // ── Settings Labels ──
    static var liquidGlass: String { "Liquid Glass" } // Brand name, no translate
    static var liquidGlassSub: String { lang == .es ? "Efecto translúcido" : "Transparent notch effect" }
    
    static var eyeControlLabel: String { lang == .es ? "Control Ocular" : "Eye Control" }
    static var eyeControlSub: String { lang == .es ? "Detección de gestos" : "Hands-free gesture detection" }
    
    static var hapticFeedback: String { lang == .es ? "Hápticos" : "Haptic Feedback" }
    static var hapticSub: String { lang == .es ? "Vibración en interacciones" : "Vibration on interactions" }
    
    static var recalibrateEyes: String { lang == .es ? "Recalibrar Ojos" : "Recalibrate Eyes" }
    static var recalibrateEyesSub: String { lang == .es ? "Resetear línea base" : "Reset EAR baseline" }
    
    static var kimiAI: String { "Kimi AI" }
    static var kimiAvailable: String { lang == .es ? "Disponible · 262K contexto" : "Available · 262K context" }
    static var kimiNotFound: String { lang == .es ? "No encontrado · instala kimi CLI" : "Not found · install kimi CLI" }
    
    static var quit: String { lang == .es ? "Salir" : "Quit" }
    
    // ── Eye Control Panel ──
    static var calibrating: String { lang == .es ? "Calibrando…" : "Calibrating…" }
    static var lookAtCamera: String { lang == .es ? "Mira a la cámara" : "Look at the camera" }
    static var sensitivity: String { lang == .es ? "Sensibilidad" : "Sensitivity" }
    static var gestures: String { lang == .es ? "gestos" : "gestures" }
    static var cooldown: String { lang == .es ? "Espera" : "Cooldown" }
    static var ready: String { lang == .es ? "Listo" : "Ready" }
    static var recalibrate: String { lang == .es ? "Recalibrar" : "Recalibrate" }
    static var faceQuality: String { lang == .es ? "Rostro" : "Face" }
    
    // ── Grid Buttons ──
    static var mirror: String { lang == .es ? "Espejo" : "Mirror" }
    static var brain: String { lang == .es ? "Ideas" : "Brain" }
    static var glass: String { "Glass" }
    static var volume: String { lang == .es ? "Volumen" : "Volume" }
    static var eye: String { lang == .es ? "Ojos" : "Eyes" }
    static var settingsBtn: String { lang == .es ? "Ajustes" : "Settings" }
    static var timer: String { lang == .es ? "Reloj" : "Timer" }
    
    // ── Music ──
    static var noMusic: String { lang == .es ? "Sin música" : "No music" }
    static var nowPlaying: String { lang == .es ? "Reproduciendo" : "Now Playing" }
    
    // ── AI Bar ──
    static var aiPlaceholder: String { lang == .es ? "Pregunta algo..." : "Ask anything..." }
    static var aiThinking: String { lang == .es ? "Pensando..." : "Thinking..." }
}
