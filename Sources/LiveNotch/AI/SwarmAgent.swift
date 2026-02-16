import SwiftUI
import Combine

// ═══════════════════════════════════════════════════════════════════
// MARK: - Micro-Agent (Disposable Intelligence Unit)
// ═══════════════════════════════════════════════════════════════════

/// A lightweight, single-use agent spawned from DNA.
/// Lives for one query cycle, then dies.
struct MicroAgent {
    let id: UUID = UUID()
    let dna: AgentDNA
    let spawnedAt: Date = Date()
    var response: String = ""
    var confidence: Double = 0.0
    var processingTimeMs: Double = 0

    /// Smart multi-signal confidence scoring
    mutating func evaluate(query: String, context: SensorFusion) {
        let lowered = query.lowercased()
        let words = lowered.components(separatedBy: .whitespacesAndNewlines)
        var score = 0.0

        // ── Signal 1: Keyword matching (weighted by specificity) ──
        let matches = dna.keywords.filter { lowered.contains($0) }
        score += Double(matches.count) * 0.15

        // ── Signal 2: N-gram matching (2-word phrases score higher) ──
        if words.count >= 2 {
            for i in 0..<(words.count - 1) {
                let bigram = "\(words[i]) \(words[i+1])"
                let bigramMatches = dna.keywords.filter { bigram.contains($0) || $0.contains(bigram) }
                score += Double(bigramMatches.count) * 0.2  // Bigrams are worth more
            }
        }

        // ── Signal 3: App context boost ──
        if dna.contextBundles.contains(context.activeAppBundle) {
            score += 0.3
        }

        // ── Signal 4: DNA fitness modifier (proven agents get edge) ──
        score += dna.fitnessScore * 0.15

        // ── Signal 5: Intent alignment (from ContextMesh) ──
        let mesh = ContextMesh.shared
        switch mesh.intentSignal {
        case .debugging:
            if dna.keywords.contains("debug") || dna.keywords.contains("error") || dna.keywords.contains("fix") { score += 0.25 }
        case .coding:
            if dna.species.hasPrefix("code.") { score += 0.2 }
        case .creating:
            if dna.species.hasPrefix("creative.") { score += 0.2 }
        case .shipping:
            if dna.species.hasPrefix("infra.") { score += 0.2 }
        case .learning:
            if dna.species.hasPrefix("research.") { score += 0.15 }
        case .resting:
            if dna.species.hasPrefix("well.") { score += 0.3 }
        case .exploring:
            break
        }

        // ── Signal 6: Session momentum (recent winning species get boost) ──
        if mesh.recentWinners.contains(dna.species) {
            score += 0.1
        }
        // Language momentum: if user has been coding in Swift, boost Swift agents
        for lang in mesh.detectedLanguages {
            if dna.species.lowercased().contains(lang.lowercased()) {
                score += 0.15
            }
        }

        // ── Signal 7: Time-of-day affinity ──
        if dna.domain.contains("Wellbeing") && (context.timeOfDay == .night || context.timeOfDay == .lateNight) {
            score += 0.25
        }
        if dna.domain.contains("Creative") && context.isPlayingMusic {
            score += 0.15
        }

        // ── Signal 8: Clipboard code analysis ──
        if let clip = context.clipboardContent {
            let clipLower = clip.lowercased()
            let clipMatches = dna.keywords.filter { clipLower.contains($0) }.count
            score += Double(clipMatches) * 0.1

            // Detect language from clipboard code patterns
            if dna.species.contains("swift") && (clipLower.contains("func ") || clipLower.contains("@State") || clipLower.contains("var body")) {
                score += 0.2
            }
            if dna.species.contains("python") && (clipLower.contains("def ") || clipLower.contains("import ") && clipLower.contains("from ")) {
                score += 0.2
            }
            if dna.species.contains("javascript") && (clipLower.contains("const ") || clipLower.contains("=>") || clipLower.contains("require(")) {
                score += 0.2
            }
            if dna.species.contains("rust") && (clipLower.contains("fn ") || clipLower.contains("let mut") || clipLower.contains("impl ")) {
                score += 0.2
            }
        }

        // ── Signal 9: Query complexity scaling ──
        // Longer, more specific queries should prefer specialized agents
        if words.count > 8 && dna.species.contains(".") {
            score += 0.05  // Small boost for sub-specialists on complex queries
        }

        // ── Signal 10: UserMode domain bias ──
        // Agents matching the current mode's domains get a real boost
        let modeBias = mesh.modeDomainBias
        if !modeBias.isEmpty {
            let domainHits = modeBias.filter { dna.domain.contains($0) || dna.species.contains($0.lowercased()) }.count
            score += Double(domainHits) * 0.2
        }

        self.confidence = min(1.0, score)
    }
}
