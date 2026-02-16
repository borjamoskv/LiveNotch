import SwiftUI
import AVFoundation

// ═══════════════════════════════════════════════════
// MARK: - 🌊 Ambient Portal — Focus & Relax
// ═══════════════════════════════════════════════════
// Inspired by Portal app. Procedural ambient sounds + ambient visuals.
// Integrated into notch: tiny speaker icon → expand to scene.
// Phase 1: Sound engine (procedural noise) | Phase 2: Visual backgrounds

@MainActor
final class AmbientPortal: ObservableObject {
    static let shared = AmbientPortal()
    
    enum Scene: String, CaseIterable, Identifiable {
        case rain = "Rain"
        case forest = "Forest"
        case ocean = "Ocean"
        case fire = "Fireplace"
        case cafe = "Café"
        case night = "Night"
        case wind = "Wind"
        case stream = "Stream"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .rain: return "cloud.rain.fill"
            case .forest: return "tree.fill"
            case .ocean: return "water.waves"
            case .fire: return "flame.fill"
            case .cafe: return "cup.and.saucer.fill"
            case .night: return "moon.stars.fill"
            case .wind: return "wind"
            case .stream: return "drop.fill"
            }
        }
        
        var tint: Color {
            switch self {
            case .rain: return .blue
            case .forest: return .green
            case .ocean: return .cyan
            case .fire: return .orange
            case .cafe: return .brown
            case .night: return .indigo
            case .wind: return .gray
            case .stream: return .teal
            }
        }
        
        /// Low-pass filter frequency for scene character (Hz)
        var filterFrequency: Float {
            switch self {
            case .rain:    return 2800   // High patter
            case .forest:  return 1200   // Mid rustling
            case .ocean:   return 600    // Deep waves
            case .fire:    return 1800   // Crackling mid
            case .cafe:    return 3200   // Bright chatter
            case .night:   return 400    // Deep crickets
            case .wind:    return 800    // Low howl
            case .stream:  return 2000   // Mid-high flow
            }
        }
        
        /// Modulation rate for volume oscillation (Hz)
        var modulationRate: Float {
            switch self {
            case .rain:    return 0.3
            case .forest:  return 0.15
            case .ocean:   return 0.08   // Slow wave rhythm
            case .fire:    return 0.5    // Quick crackle
            case .cafe:    return 0.4
            case .night:   return 0.1
            case .wind:    return 0.12
            case .stream:  return 0.25
            }
        }
    }
    
    @Published var isActive: Bool = false
    @Published var activeScene: Scene? = nil
    @Published var volume: Float = 0.5 {
        didSet { updateVolume() }
    }
    
    // Audio engine
    private var audioEngine: AVAudioEngine?
    private var noiseNode: AVAudioSourceNode?
    private var eqNode: AVAudioUnitEQ?
    private var phase: Float = 0
    
    private init() {}
    
    func activate(_ scene: Scene) {
        activeScene = scene
        isActive = true
        startAudioEngine(for: scene)
        HapticManager.shared.play(.soft)
    }
    
    func deactivate() {
        stopAudioEngine()
        isActive = false
        activeScene = nil
        HapticManager.shared.play(.soft)
    }
    
    func toggle(_ scene: Scene) {
        if activeScene == scene { deactivate() }
        else { activate(scene) }
    }
    
    // MARK: - Audio Engine
    
    private func startAudioEngine(for scene: Scene) {
        stopAudioEngine()
        
        let engine = AVAudioEngine()
        let sampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        let filterFreq = scene.filterFrequency
        let modRate = scene.modulationRate
        let vol = self.volume
        
        // Procedural noise generator with scene-specific modulation
        var localPhase: Float = 0
        var b0: Float = 0, b1: Float = 0, b2: Float = 0, b3: Float = 0, b4: Float = 0, b5: Float = 0, b6: Float = 0
        
        let sourceNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0..<Int(frameCount) {
                // Generate white noise
                let white = Float.random(in: -1...1)
                
                // Pink noise filter (Paul Kellet's approximation)
                b0 = 0.99886 * b0 + white * 0.0555179
                b1 = 0.99332 * b1 + white * 0.0750759
                b2 = 0.96900 * b2 + white * 0.1538520
                b3 = 0.86650 * b3 + white * 0.3104856
                b4 = 0.55000 * b4 + white * 0.5329522
                b5 = -0.7616 * b5 - white * 0.0168980
                let pink = (b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362) * 0.11
                b6 = white * 0.115926
                
                // Simple low-pass filter approximation
                let rc: Float = 1.0 / (2.0 * .pi * filterFreq)
                let dt: Float = 1.0 / Float(sampleRate)
                let alpha = dt / (rc + dt)
                let filtered = alpha * pink + (1.0 - alpha) * white * 0.3
                
                // Volume modulation (gentle swell)
                localPhase += modRate / Float(sampleRate)
                if localPhase > 1.0 { localPhase -= 1.0 }
                let modulation = 0.7 + 0.3 * sin(localPhase * 2.0 * .pi)
                
                let sample = filtered * vol * modulation * 0.4 // Master gain
                
                for buffer in ablPointer {
                    let buf = buffer.mData?.assumingMemoryBound(to: Float.self)
                    buf?[frame] = sample
                }
            }
            return noErr
        }
        
        // EQ for scene character
        let eq = AVAudioUnitEQ(numberOfBands: 1)
        let band = eq.bands[0]
        band.filterType = .lowPass
        band.frequency = scene.filterFrequency
        band.bandwidth = 1.0
        band.bypass = false
        
        engine.attach(sourceNode)
        engine.attach(eq)
        
        let format = engine.outputNode.outputFormat(forBus: 0)
        engine.connect(sourceNode, to: eq, format: format)
        engine.connect(eq, to: engine.mainMixerNode, format: format)
        
        do {
            try engine.start()
            self.audioEngine = engine
            self.noiseNode = sourceNode
            self.eqNode = eq
            NSLog("🌊 AmbientPortal: Started scene '%@'", scene.rawValue)
        } catch {
            NSLog("🌊 AmbientPortal: Failed to start — %@", error.localizedDescription)
        }
    }
    
    private func stopAudioEngine() {
        audioEngine?.stop()
        if let node = noiseNode { audioEngine?.detach(node) }
        if let eq = eqNode { audioEngine?.detach(eq) }
        audioEngine = nil
        noiseNode = nil
        eqNode = nil
    }
    
    private func updateVolume() {
        // Volume is applied in the render callback via captured reference
        // Restart engine with new volume if active
        if let scene = activeScene, isActive {
            startAudioEngine(for: scene)
        }
    }
}

// ═══════════════════════════════════════════════════
// MARK: - View
// ═══════════════════════════════════════════════════

struct AmbientPortalView: View {
    @ObservedObject var portal = AmbientPortal.shared
    @ObservedObject var theme = ThemeEngine.shared
    
    let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)
    
    var body: some View {
        VStack(spacing: 8) {
            // Header
            HStack {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.green.opacity(0.6))
                Text("AMBIENT")
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))
                    .tracking(1.5)
                Spacer()
                if portal.isActive {
                    Circle()
                        .fill(.green.opacity(0.5))
                        .frame(width: 4, height: 4)
                }
            }
            
            // Scene grid
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(AmbientPortal.Scene.allCases) { scene in
                    Button(action: { portal.toggle(scene) }) {
                        VStack(spacing: 3) {
                            Image(systemName: scene.icon)
                                .font(.system(size: 14))
                                .foregroundColor(portal.activeScene == scene ? scene.tint : .white.opacity(0.3))
                            Text(scene.rawValue)
                                .font(.system(size: 7, weight: .medium))
                                .foregroundColor(.white.opacity(portal.activeScene == scene ? 0.7 : 0.25))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(portal.activeScene == scene ? scene.tint.opacity(0.1) : Color.white.opacity(0.02))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(portal.activeScene == scene ? scene.tint.opacity(0.15) : Color.clear, lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(10)
    }
}
