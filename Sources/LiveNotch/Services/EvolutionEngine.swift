import SwiftUI
import Combine
import Foundation

// ═══════════════════════════════════════════════════════════
// MARK: - 🧬 EvolutionEngine — Organic Interface Genetics
// ═══════════════════════════════════════════════════════════
// The UI is not static. It is a living organism that evolves
// based on user interaction (Darwinian selection).
// "Survival of the most useful."

@MainActor
final class EvolutionEngine: ObservableObject {
    static let shared = EvolutionEngine()
    private let log = NotchLog.make("EvolutionEngine")
    
    // ─── DNA Structure ───
    struct Genome: Codable, Equatable {
        var widgetScale: Double = 1.0         // 0.8 ... 1.2
        var glowIntensity: Double = 1.0       // 0.5 ... 1.5
        var responseSpeed: Double = 1.0       // 0.5 ... 1.5 (animations)
        var dominantHueShift: Double = 0.0    // -30 ... +30 degrees
        var cornerRadius: Double = 12.0       // 8 ... 20
        var usageScore: Double = 0.0          // Fitness metric
        var generation: Int = 0
    }
    
    @Published var currentGenome = Genome()
    @Published var generationalStats: String = "Gen 0 • Fitness 0.0"
    
    // ─── Usage Tracking ───
    private var interactionCount: Int = 0
    private var sessionDuration: TimeInterval = 0
    private var startTime: Date = Date()
    private var lastInteraction: Date = Date()
    
    private let persistenceKey = NotchPersistence.Key.evolutionGenome
    
    init() {
        loadGenome()
        startEvolutionCycle()
        log.info("Evolution Engine Online — Gen \(currentGenome.generation)")
    }
    
    // MARK: - 🧬 Genetic Algorithm
    // ═══════════════════════════════════════════════════
    
    /// Triggered nightly or on long idle
    func evolve() {
        let fitness = calculateFitness()
        log.info("Evolving... Current Fitness: \(String(format: "%.2f", fitness))")
        
        // 1. Selection: Compare with previous generation's best
        // (Simplified: We mutate the current successful genome)
        
        let mutationRate = 0.1 // 10% variance
        var nextGen = currentGenome
        
        // 2. Mutation: Random drift based on usage patterns
        if fitness > 0.8 {
            // High engagement: Specialize further
            nextGen.widgetScale = mutate(val: nextGen.widgetScale, rate: 0.02, min: 0.9, max: 1.1)
            nextGen.responseSpeed = mutate(val: nextGen.responseSpeed, rate: 0.05, min: 0.8, max: 1.5)
        } else {
            // Low engagement: Try radical changes
            nextGen.dominantHueShift = mutate(val: nextGen.dominantHueShift, rate: 5.0, min: -30, max: 30)
            nextGen.glowIntensity = mutate(val: nextGen.glowIntensity, rate: 0.2, min: 0.5, max: 1.5)
        }
        
        // 3. Inheritance
        nextGen.generation += 1
        nextGen.usageScore = 0 // Reset for new trial
        
        // 4. Apply
        self.currentGenome = nextGen
        self.generationalStats = "Gen \(nextGen.generation) • Last Fitness \(String(format: "%.2f", fitness))"
        saveGenome()
        
        resetTracking()
    }
    
    private func mutate(val: Double, rate: Double, min: Double, max: Double) -> Double {
        let drift = Double.random(in: -rate...rate)
        return Swift.min(Swift.max(val + drift, min), max)
    }
    
    // MARK: - 📊 Fitness Function
    // ═══════════════════════════════════════════════════
    
    func trackInteraction(_ type: InteractionType) {
        interactionCount += 1
        lastInteraction = Date()
        
        switch type {
        case .click: currentGenome.usageScore += 1.0
        case .hover: currentGenome.usageScore += 0.2
        case .gesture: currentGenome.usageScore += 1.5
        case .dismiss: currentGenome.usageScore -= 0.5 // Negative reinforcement
        }
    }
    
    private func calculateFitness() -> Double {
        let duration = Date().timeIntervalSince(startTime)
        guard duration > 60 else { return 0 } // Ignore short sessions
        
        // Engagement Density: Interactions per minute
        let density = Double(interactionCount) / (duration / 60.0)
        
        // Normalized score (0..1 typical, can exceed)
        return min(density / 5.0, 2.0) 
    }
    
    private func resetTracking() {
        interactionCount = 0
        startTime = Date()
        lastInteraction = Date()
    }
    
    // MARK: - Persistence
    // ═══════════════════════════════════════════════════
    
    private func saveGenome() {
        NotchPersistence.shared.set(persistenceKey, value: currentGenome)
    }
    
    private func loadGenome() {
        if let saved: Genome = NotchPersistence.shared.getCodable(persistenceKey, as: Genome.self) {
            self.currentGenome = saved
        }
    }
    
    private func startEvolutionCycle() {
        // Evolve every 24h or significantly
        // For demo: simulation speed
        Timer.scheduledTimer(withTimeInterval: 3600 * 24, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.evolve() }
        }
    }
    
    enum InteractionType {
        case click, hover, gesture, dismiss
    }
}
