import SwiftUI
import Combine
import Foundation

// ═══════════════════════════════════════════════════════════
// MARK: - 🌊 BioLumEngine — Bioluminescent Notch Visualizer
// ═══════════════════════════════════════════════════════════
// 10 distinct visualization modes, each "piloted" by a
// swarm agent persona. The notch border becomes a living
// organism that breathes, pulses, and shifts color based
// on system state — perceived peripherally, never interrupting.
//
// Philosophy: NO TEXT. Pure chromatic perception.
// The user *feels* system state through color temperature.

@MainActor
final class BioLumEngine: ObservableObject {
    
    // ─── Active Mode ───
    @Published var activeMode: VisualizationMode = .thermalBreath
    @Published var glowColor: Color = .cyan
    @Published var glowIntensity: Double = 0.15
    @Published var pulseRate: Double = 1.0        // Hz — breathing speed
    @Published var secondaryColor: Color = .clear
    @Published var patternPhase: Double = 0       // 0..1 animation cycle
    
    // ─── System Inputs ───
    @Published var cpuLoad: Double = 0             // 0..100
    @Published var ramPressure: Double = 0          // 0..100
    @Published var thermalState: ProcessInfo.ThermalState = .nominal
    @Published var batteryLevel: Double = 1.0       // 0..1
    @Published var isCharging: Bool = false
    @Published var networkActivity: Double = 0      // bytes/sec normalized
    
    // ─── Swarm Integration ───
    @Published var activeAgentCount: Int = 0
    @Published var swarmWorkload: Double = 0        // 0..1
    
    private var cancellables = Set<AnyCancellable>()
    private var animationTimer: AnyCancellable?
    
    // ═══════════════════════════════════════════════════
    // MARK: - 10 Visualization Modes
    // ═══════════════════════════════════════════════════
    
    enum VisualizationMode: String, CaseIterable, Identifiable {
        case thermalBreath       // 1. CPU/thermal → cool blue ↔ hot amber ↔ critical red
        case memoryTide          // 2. RAM pressure → rising liquid level around notch
        case heartbeat           // 3. System pulse — rhythmic glow synced to CPU activity
        case auroraFlow          // 4. Gradient aurora that shifts with time-of-day
        case swarmhive           // 5. Agent activity → firefly-like sparkle pattern
        case networkRipple       // 6. Network I/O → water ripple emanating from notch
        case focusZen            // 7. Deep breathing guide — slow 4-7-8 cycle
        case energyField         // 8. Battery → electric field intensity
        case circadian           // 9. Time-of-day natural light temperature
        case sentient            // 10. ALL inputs combined — the notch "feels" everything
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .thermalBreath:  return "Thermal Breath"
            case .memoryTide:    return "Memory Tide"
            case .heartbeat:     return "Heartbeat"
            case .auroraFlow:    return "Aurora Flow"
            case .swarmhive:     return "Swarm Hive"
            case .networkRipple: return "Network Ripple"
            case .focusZen:      return "Focus Zen"
            case .energyField:   return "Energy Field"
            case .circadian:     return "Circadian"
            case .sentient:      return "Sentient"
            }
        }
        
        var icon: String {
            switch self {
            case .thermalBreath:  return "flame"
            case .memoryTide:    return "water.waves"
            case .heartbeat:     return "heart.fill"
            case .auroraFlow:    return "sparkles"
            case .swarmhive:     return "ant.fill"
            case .networkRipple: return "wifi"
            case .focusZen:      return "leaf.fill"
            case .energyField:   return "bolt.fill"
            case .circadian:     return "sun.horizon.fill"
            case .sentient:      return "brain.head.profile.fill"
            }
        }
        
        /// The swarm agent role that "pilots" this mode
        var agentRole: AgentRole {
            switch self {
            case .thermalBreath:  return .analyst
            case .memoryTide:    return .optimizer
            case .heartbeat:     return .guardian
            case .auroraFlow:    return .designer
            case .swarmhive:     return .researcher
            case .networkRipple: return .analyst
            case .focusZen:      return .guardian
            case .energyField:   return .optimizer
            case .circadian:     return .designer
            case .sentient:      return .coder
            }
        }
    }
    
    // ═══════════════════════════════════════════════════
    // MARK: - Init & System Binding
    // ═══════════════════════════════════════════════════
    
    init() {
        bindSystemMonitor()
        startAnimationLoop()
    }
    
    private func bindSystemMonitor() {
        // Subscribe to SystemMonitor for CPU/RAM
        let monitor = SystemMonitor.shared
        
        // Poll system state periodically via SmartPolling
        SmartPolling.shared.register("biolum.state", interval: .fixed(2.0)) { [weak self] in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.cpuLoad = monitor.cpuUsage
                self.ramPressure = monitor.ramUsage
                self.thermalState = ProcessInfo.processInfo.thermalState
                self.updateMode()
            }
        }
    }
    
    private func startAnimationLoop() {
        // PERF: 10fps is sufficient for ambient glow transitions (was 30fps)
        animationTimer = Timer.publish(every: 1.0 / 10.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }
    
    func stop() {
        animationTimer?.cancel()
        animationTimer = nil
    }

    // deinit removed - AnyCancellable handles cleanup automatically

    
    // ═══════════════════════════════════════════════════
    // MARK: - Animation Tick (10fps)
    // ═══════════════════════════════════════════════════
    
    private func tick() {
        // Advance phase — scaled to 10fps (was /30.0)
        patternPhase += (pulseRate / 10.0)
        if patternPhase > 1.0 { patternPhase -= 1.0 }
        
        // Compute glow based on active mode
        switch activeMode {
        case .thermalBreath:
            computeThermalBreath()
        case .memoryTide:
            computeMemoryTide()
        case .heartbeat:
            computeHeartbeat()
        case .auroraFlow:
            computeAuroraFlow()
        case .swarmhive:
            computeSwarmHive()
        case .networkRipple:
            computeNetworkRipple()
        case .focusZen:
            computeFocusZen()
        case .energyField:
            computeEnergyField()
        case .circadian:
            computeCircadian()
        case .sentient:
            computeSentient()
        }
    }
    
    private func updateMode() {
        // Mode stays manual — user/swarm selects it
        // But intensity auto-adapts to system
    }
    
    // ═══════════════════════════════════════════════════
    // MARK: - Mode Computations
    // ═══════════════════════════════════════════════════
    
    // 1. THERMAL BREATH — cool↔warm↔hot based on CPU + thermal
    private func computeThermalBreath() {
        let t = cpuLoad / 100.0
        let breathCycle = sin(patternPhase * .pi * 2) * 0.5 + 0.5
        
        // Color temperature: cyan (cold) → orange (warm) → red (critical)
        let hue: Double
        switch thermalState {
        case .nominal:   hue = 0.55 - (t * 0.2)   // 0.55 (cyan) → 0.35 (green-ish)
        case .fair:      hue = 0.15 - (t * 0.05)   // warm amber
        case .serious:   hue = 0.08                 // orange-red
        case .critical:  hue = 0.0                  // pure red
        @unknown default: hue = 0.55
        }
        
        glowColor = Color(hue: max(0, hue), saturation: 0.7 + (t * 0.3), brightness: 0.9)
        glowIntensity = 0.08 + (t * 0.25) + (breathCycle * 0.08)
        pulseRate = 0.3 + (t * 1.2) // Breathes faster under load
    }
    
    // 2. MEMORY TIDE — rising liquid that fills based on RAM
    private func computeMemoryTide() {
        let pressure = ramPressure / 100.0
        let wave = sin(patternPhase * .pi * 2) * 0.03
        
        // Blue → purple → magenta as pressure rises
        let hue = 0.6 - (pressure * 0.25)
        glowColor = Color(hue: max(0, hue), saturation: 0.6, brightness: 0.85)
        glowIntensity = (pressure * 0.3) + wave + 0.05
        secondaryColor = Color(hue: max(0, hue - 0.1), saturation: 0.8, brightness: 0.7)
        pulseRate = 0.2 + (pressure * 0.3) // Slow tide
    }
    
    // 3. HEARTBEAT — sharp pulse synced to CPU spikes
    private func computeHeartbeat() {
        let t = cpuLoad / 100.0
        // Double-bump heartbeat pattern: lub-dub
        let phase2 = patternPhase * 2.0
        let lub = max(0, sin(phase2 * .pi * 2) * 2 - 1)
        let dub = max(0, sin((phase2 + 0.3) * .pi * 2) * 1.5 - 1)
        let beat = max(lub, dub)
        
        glowColor = Color(hue: 0.0, saturation: 0.8, brightness: 0.9) // Red pulse
        glowIntensity = 0.03 + (beat * (0.15 + t * 0.2))
        pulseRate = 0.8 + (t * 0.8) // 48-96 BPM equivalent
    }
    
    // 4. AURORA FLOW — slow shifting gradient tied to time
    private func computeAuroraFlow() {
        let hour = Double(Calendar.current.component(.hour, from: Date()))
        let baseHue = (hour / 24.0) * 0.3 + 0.4 // Cycles through green-blue-purple
        let drift = sin(patternPhase * .pi * 2) * 0.1
        
        glowColor = Color(hue: baseHue + drift, saturation: 0.5, brightness: 0.8)
        secondaryColor = Color(hue: baseHue + drift + 0.15, saturation: 0.6, brightness: 0.75)
        glowIntensity = 0.1 + (sin(patternPhase * .pi) * 0.06)
        pulseRate = 0.15 // Very slow, hypnotic
    }
    
    // 5. SWARM HIVE — firefly sparkle based on agent activity
    private func computeSwarmHive() {
        let activity = swarmWorkload
        // Random sparkle using phase
        let sparkle = abs(sin(patternPhase * 17.3)) * abs(cos(patternPhase * 23.7))
        
        // Amber-gold base for hive
        glowColor = Color(hue: 0.12, saturation: 0.9, brightness: 0.95)
        secondaryColor = Color(hue: 0.08, saturation: 0.7, brightness: 0.8)
        glowIntensity = 0.05 + (activity * 0.2) + (sparkle * 0.15)
        pulseRate = 0.5 + (activity * 2.0) // Buzzing increases with activity
    }
    
    // 6. NETWORK RIPPLE — emanating waves on I/O
    private func computeNetworkRipple() {
        let net = min(1.0, networkActivity)
        let ripple = sin(patternPhase * .pi * 4) * 0.5 + 0.5
        
        // Teal for download, violet for upload mix
        glowColor = Color(hue: 0.5, saturation: 0.6, brightness: 0.85)
        glowIntensity = 0.04 + (net * ripple * 0.25)
        pulseRate = 0.3 + (net * 1.5)
    }
    
    // 7. FOCUS ZEN — 4-7-8 breathing guide
    private func computeFocusZen() {
        // 4 in, 7 hold, 8 out = 19 beats total
        let totalBeats: Double = 19.0
        let currentBeat = patternPhase * totalBeats
        
        let brightness: Double
        if currentBeat < 4 {
            brightness = currentBeat / 4.0 // Inhale — rise
        } else if currentBeat < 11 {
            brightness = 1.0                // Hold — peak
        } else {
            brightness = 1.0 - ((currentBeat - 11.0) / 8.0) // Exhale — fall
        }
        
        glowColor = Color(hue: 0.35, saturation: 0.4, brightness: 0.7) // Soft green
        secondaryColor = Color(hue: 0.45, saturation: 0.3, brightness: 0.6)
        glowIntensity = 0.03 + (brightness * 0.15)
        pulseRate = 1.0 / totalBeats * 0.5 // Very slow cycle
    }
    
    // 8. ENERGY FIELD — battery level as electric intensity
    private func computeEnergyField() {
        let level = batteryLevel
        let crackle = abs(sin(patternPhase * 31.4)) > 0.85 ? 0.3 : 0.0
        
        // Green full → yellow mid → red low
        let hue = level * 0.33 // 0 (red) → 0.33 (green)
        glowColor = Color(hue: hue, saturation: 0.8, brightness: 0.9)
        
        if isCharging {
            // Lightning effect when charging
            glowIntensity = 0.15 + crackle
            secondaryColor = Color(hue: 0.17, saturation: 0.9, brightness: 1.0) // Electric yellow
            pulseRate = 2.0
        } else {
            glowIntensity = 0.05 + ((1.0 - level) * 0.15) // Glows more urgent as battery drops
            secondaryColor = .clear
            pulseRate = 0.3 + ((1.0 - level) * 0.5)
        }
    }
    
    // 9. CIRCADIAN — natural daylight temperature
    private func computeCircadian() {
        let hour = Double(Calendar.current.component(.hour, from: Date()))
        let minute = Double(Calendar.current.component(.minute, from: Date()))
        let timeOfDay = (hour + minute / 60.0) / 24.0
        
        // Dawn(6h)=warm amber → Noon(12h)=cool white → Dusk(18h)=warm orange → Night(0h)=deep blue
        let hue: Double
        let sat: Double
        let bright: Double
        
        if timeOfDay < 0.25 {
            // Night → pre-dawn: deep blue → warm amber
            let t = timeOfDay / 0.25
            hue = 0.65 - (t * 0.5)
            sat = 0.6
            bright = 0.4 + (t * 0.3)
        } else if timeOfDay < 0.5 {
            // Morning → noon: warm → cool daylight
            let t = (timeOfDay - 0.25) / 0.25
            hue = 0.15 + (t * 0.4)
            sat = 0.3 + (t * 0.1)
            bright = 0.7 + (t * 0.2)
        } else if timeOfDay < 0.75 {
            // Noon → dusk: cool → warm orange
            let t = (timeOfDay - 0.5) / 0.25
            hue = 0.55 - (t * 0.45)
            sat = 0.4 + (t * 0.3)
            bright = 0.9 - (t * 0.2)
        } else {
            // Dusk → night: warm orange → deep blue
            let t = (timeOfDay - 0.75) / 0.25
            hue = 0.1 + (t * 0.55)
            sat = 0.7 - (t * 0.1)
            bright = 0.7 - (t * 0.3)
        }
        
        let breathe = sin(patternPhase * .pi * 2) * 0.03
        glowColor = Color(hue: hue, saturation: sat, brightness: bright)
        glowIntensity = 0.08 + breathe
        pulseRate = 0.1 // Ultra slow natural rhythm
    }
    
    // 10. SENTIENT — all inputs synthesized into one living response
    private func computeSentient() {
        let cpu = cpuLoad / 100.0
        let ram = ramPressure / 100.0
        let agents = swarmWorkload
        let battery = batteryLevel
        
        // Composite "arousal" level
        let arousal = (cpu * 0.35 + ram * 0.25 + agents * 0.2 + (1.0 - battery) * 0.2)
        
        // Hue drifts based on dominant stressor
        let baseHue: Double
        if cpu > ram && cpu > agents {
            baseHue = 0.05 // CPU dominant → warm/red
        } else if ram > agents {
            baseHue = 0.7  // RAM dominant → purple
        } else if agents > 0.3 {
            baseHue = 0.12 // Swarm dominant → amber
        } else {
            baseHue = 0.55 // Calm → cyan
        }
        
        // Mix with time-of-day bias
        let hour = Double(Calendar.current.component(.hour, from: Date()))
        let timeBias = sin((hour / 24.0) * .pi * 2) * 0.1
        
        let finalHue = max(0, min(1, baseHue + timeBias + sin(patternPhase * .pi * 2) * 0.05))
        
        glowColor = Color(hue: finalHue, saturation: 0.5 + (arousal * 0.4), brightness: 0.8)
        secondaryColor = Color(hue: max(0, finalHue + 0.15), saturation: 0.6, brightness: 0.7)
        glowIntensity = 0.05 + (arousal * 0.25) + (sin(patternPhase * .pi * 2) * arousal * 0.08)
        pulseRate = 0.2 + (arousal * 1.3)
    }
    
    // ═══════════════════════════════════════════════════
    // MARK: - Swarm Integration
    // ═══════════════════════════════════════════════════
    
    /// Feed swarm state into the engine
    func updateSwarmState(agentCount: Int, workload: Double) {
        self.activeAgentCount = agentCount
        self.swarmWorkload = workload
    }
    
    /// Cycle to next mode
    func nextMode() {
        let modes = VisualizationMode.allCases
        guard let idx = modes.firstIndex(of: activeMode) else { return }
        let next = modes.index(after: idx)
        withAnimation(DS.Spring.island) {
            activeMode = next < modes.endIndex ? modes[next] : modes[0]
        }
    }
    
    /// Set specific mode
    func setMode(_ mode: VisualizationMode) {
        withAnimation(DS.Spring.island) {
            activeMode = mode
        }
    }
    
    // ═══════════════════════════════════════════════════
    // MARK: - View Helpers
    // ═══════════════════════════════════════════════════
    
    /// The computed glow for the wing border — used by NotchViews
    var bioGlowGradient: LinearGradient {
        LinearGradient(
            colors: [
                .clear,
                glowColor.opacity(glowIntensity),
                secondaryColor != .clear ? secondaryColor.opacity(glowIntensity * 0.6) : glowColor.opacity(glowIntensity * 0.8),
                .clear
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    /// Shadow color with current bio-glow
    var bioShadowColor: Color {
        glowColor.opacity(glowIntensity * 0.5)
    }
    
    /// Pulse animation duration for SwiftUI
    var pulseDuration: Double {
        max(0.3, 1.0 / max(0.1, pulseRate))
    }
}
