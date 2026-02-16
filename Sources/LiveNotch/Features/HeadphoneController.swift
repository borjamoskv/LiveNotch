import SwiftUI
import Combine

// ═══════════════════════════════════════════════════════════
// MARK: - 🎧 HeadphoneController — GOD MODE
// ═══════════════════════════════════════════════════════════
// Controlador soberano de auriculares. No solo controla — PIENSA.
//
// Intelligence Layer:
//   • Meeting detected → auto Conversation Boost + Transparency
//   • Flow state → auto ANC (máximo aislamiento)
//   • Music playing → auto ANC, paused → Transparency
//   • Sleep detected → auto Off (ahorro batería)
//   • Low battery → haptic warning + auto reduce features
//
// Coordination:
//   • MusicController — volume normalization, play state
//   • NervousSystem — mood, flow, meetings, sleep
//   • AirPodsBluetoothService — hardware detection

@MainActor
final class HeadphoneController: ObservableObject {
    static let shared = HeadphoneController()
    private let log = NotchLog.make("🎧 HP")
    
    // ─── Hardware State ───
    @Published var isConnected: Bool = false
    @Published var deviceName: String = "AirPods Pro"
    @Published var batteryLeft: Int = -1
    @Published var batteryRight: Int = -1
    @Published var batteryCase: Int = -1
    @Published var isInEar: Bool = false
    
    // ─── ANC ───
    @Published var ancMode: ANCMode = .off
    @Published var autoANC: Bool = true             // god mode: auto-switch ANC
    @Published var lastAutoReason: String? = nil     // why auto-switched
    
    // ─── Audio Features ───
    @Published var spatialAudio: Bool = false
    @Published var headTracking: Bool = true
    @Published var adaptiveEQ: Bool = true
    @Published var conversationBoost: Bool = false
    
    // ─── Intelligence ───
    @Published var intelligenceLog: [IntelEvent] = []
    
    // ─── Internal ───
    private let bt = AirPodsBluetoothService.shared
    private var subs = Set<AnyCancellable>()
    private var contextTimer: AnyCancellable?
    
    // ═══════════════════════════════════════════════════
    // MARK: - Types
    // ═══════════════════════════════════════════════════
    
    enum ANCMode: String, CaseIterable {
        case off = "Off"
        case noiseCancel = "Noise Cancel"
        case transparency = "Transparency"
        case adaptive = "Adaptive"
        
        var icon: String {
            switch self {
            case .off: return "powersleep"
            case .noiseCancel: return "person.fill.turn.down"
            case .transparency: return "speaker.wave.2.fill"
            case .adaptive: return "hearingdevice.ear"
            }
        }
        
        var short: String {
            switch self {
            case .off: return "Off"
            case .noiseCancel: return "ANC"
            case .transparency: return "Transp."
            case .adaptive: return "Adaptive"
            }
        }
        
        var neon: Color {
            switch self {
            case .off: return .white.opacity(0.2)
            case .noiseCancel: return Color(red: 0.0, green: 0.85, blue: 1.0)
            case .transparency: return Color(red: 0.3, green: 1.0, blue: 0.5)
            case .adaptive: return Color(red: 0.75, green: 0.35, blue: 1.0)
            }
        }
    }
    
    struct IntelEvent: Identifiable {
        let id = UUID()
        let time = Date()
        let icon: String
        let message: String
        let color: Color
    }
    
    // ═══════════════════════════════════════════════════
    // MARK: - Init
    // ═══════════════════════════════════════════════════
    
    init() {
        bindBluetooth()
        startContextEngine()
        log.info("⚡ HeadphoneController GOD MODE active")
    }
    
    private func bindBluetooth() {
        bt.$isAirPodsConnected.assign(to: &$isConnected)
        bt.$airPodsName.assign(to: &$deviceName)
        bt.$batteryLeft.assign(to: &$batteryLeft)
        bt.$batteryRight.assign(to: &$batteryRight)
        bt.$batteryCase.assign(to: &$batteryCase)
        bt.$isInEar.assign(to: &$isInEar)
    }
    
    // ═══════════════════════════════════════════════════
    // MARK: - ⚡ Context Engine (GOD MODE)
    // ═══════════════════════════════════════════════════
    
    private func startContextEngine() {
        // Every 5s: read MusicController + NervousSystem → decide
        contextTimer = Timer.publish(every: 5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.evaluateContext()
            }
    }
    
    private func evaluateContext() {
        guard autoANC, isConnected else { return }
        
        let ns = NervousSystem.shared
        let oldMode = ancMode
        
        // ── Priority 1: Meeting → Transparency + ConvBoost ──
        if ns.isMeetingActive {
            if ancMode != .transparency {
                ancMode = .transparency
                if !conversationBoost { conversationBoost = true }
                intel("🎤", "Meeting → Transparency + Boost", .green)
            }
            return
        }
        
        // ── Turn off ConvBoost when meeting ends ──
        if conversationBoost && !ns.isMeetingActive {
            conversationBoost = false
            intel("🔇", "Meeting ended → Boost off", .orange)
        }
        
        // ── Priority 2: Sleep → Off (save battery) ──
        if ns.isAsleep {
            if ancMode != .off {
                ancMode = .off
                intel("😴", "Sleep → ANC off (battery save)", .gray)
            }
            return
        }
        
        // ── Priority 3: Flow state → ANC max isolation ──
        if ns.isInFlowState {
            if ancMode != .noiseCancel {
                ancMode = .noiseCancel
                intel("🧠", "Flow state → ANC max isolation", .cyan)
            }
            return
        }
        
        // ── Priority 4: High anxiety → Adaptive (let some sound in) ──
        if ns.anxietyLevel > 0.7 {
            if ancMode != .adaptive {
                ancMode = .adaptive
                intel("⚡", "High anxiety → Adaptive mode", .purple)
            }
            return
        }
        
        // ── Priority 5: Music state ──
        // (MusicController is not a @Published dependency here,
        //  but we read its state directly)
        let musicPlaying = NervousSystem.shared.isPlayingMusic
        if musicPlaying && ancMode != .noiseCancel {
            ancMode = .noiseCancel
            intel("🎵", "Music playing → ANC on", .cyan)
            return
        }
        if !musicPlaying && ancMode == .noiseCancel && !ns.isInFlowState {
            ancMode = .transparency
            intel("⏸", "Music paused → Transparency", .green)
            return
        }
        
        // ── Battery warnings ──
        if isBatteryLow && oldMode == ancMode {
            if batteryLeft >= 0 && batteryLeft < 10 {
                intel("🪫", "Battery critical: L\(batteryLeft)% R\(batteryRight)%", .red)
                HapticManager.shared.play(.error)
            } else if batteryLeft >= 0 && batteryLeft < 20 {
                intel("🔋", "Battery low: L\(batteryLeft)% R\(batteryRight)%", .orange)
            }
        }
        
        if oldMode != ancMode {
            lastAutoReason = intelligenceLog.first?.message
            HapticManager.shared.play(.subtle)
        }
    }
    
    private func intel(_ icon: String, _ msg: String, _ color: Color) {
        let event = IntelEvent(icon: icon, message: msg, color: color)
        intelligenceLog.insert(event, at: 0)
        if intelligenceLog.count > 20 { intelligenceLog = Array(intelligenceLog.prefix(20)) }
        log.info("\(icon) \(msg)")
    }
    
    // ═══════════════════════════════════════════════════
    // MARK: - Manual Actions
    // ═══════════════════════════════════════════════════
    
    func cycleANC() {
        autoANC = false // manual override disables auto
        let all = ANCMode.allCases
        guard let i = all.firstIndex(of: ancMode) else { return }
        ancMode = all[(i + 1) % all.count]
        intel("👆", "Manual → \(ancMode.short)", .white)
    }
    
    func setANC(_ mode: ANCMode) {
        guard mode != ancMode else { return }
        autoANC = false
        ancMode = mode
        intel("👆", "Manual → \(mode.short)", .white)
    }
    
    func toggleAutoANC() {
        autoANC.toggle()
        intel(autoANC ? "🤖" : "👆", autoANC ? "Auto ANC enabled" : "Manual mode", autoANC ? .cyan : .white)
    }
    
    func toggleSpatialAudio() {
        spatialAudio.toggle()
        if !spatialAudio { headTracking = false }
        intel(spatialAudio ? "🔊" : "🔇", "Spatial \(spatialAudio ? "ON" : "OFF")", .cyan)
    }
    
    func toggleHeadTracking() {
        guard spatialAudio else { return }
        headTracking.toggle()
    }
    
    func toggleAdaptiveEQ() {
        adaptiveEQ.toggle()
    }
    
    func toggleConversationBoost() {
        conversationBoost.toggle()
        intel(conversationBoost ? "🗣" : "🔇", "Boost \(conversationBoost ? "ON" : "OFF")", .green)
    }
    
    func refresh() { bt.refreshState() }
    
    // ═══════════════════════════════════════════════════
    // MARK: - Computed
    // ═══════════════════════════════════════════════════
    
    var overallBattery: Double { bt.overallBattery }
    var isBatteryLow: Bool { (batteryLeft >= 0 && batteryLeft < 20) || (batteryRight >= 0 && batteryRight < 20) }
    var isBatteryCritical: Bool { (batteryLeft >= 0 && batteryLeft < 10) || (batteryRight >= 0 && batteryRight < 10) }
}
