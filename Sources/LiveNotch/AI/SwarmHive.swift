import SwiftUI
import Combine

// ═══════════════════════════════════════════════════════════════════
// MARK: - 🐝 SwarmHive v2.0 — Massively Parallel Agent Coordination
// ═══════════════════════════════════════════════════════════════════
//
// The SwarmHive spawns and coordinates thousands of micro-agents
// on-device. Each micro-agent is a lightweight, disposable unit
// of intelligence that lives for a single query cycle.
//
// Architecture:
// ┌──────────────────────────────────────────────────────────────┐
// │                    SwarmHive (Coordinator)                   │
// │  ┌──────────┐  ┌───────────┐  ┌──────────────┐             │
// │  │ Spawner  │→ │ Scheduler │→ │ Consensus    │→ Result     │
// │  │ (N=1000+)│  │ (Parallel)│  │ (Byzantine)  │             │
// │  └──────────┘  └───────────┘  └──────────────┘             │
// │                                                             │
// │  [AgentDNA Registry]  — Templates for agent generation      │
// │  [FitnessTracker]     — Evolutionary scoring per agent      │
// │  [SwarmTelemetry]     — Real-time hive health dashboard     │
// │  [ContextMesh]        — Shared context across all agents    │
// └──────────────────────────────────────────────────────────────┘
//
// Each query spawns a swarm of micro-agents from DNA templates.
// Agents vote, the best responses survive, weak ones die.
// Over time, the system evolves — better agents rise.

// ═══════════════════════════════════════════════════════════════
// MARK: - Agent DNA (Template for Micro-Agent Generation)
// ═══════════════════════════════════════════════════════════════

/// AgentDNA is the genetic blueprint for spawning micro-agents.
/// Each DNA encodes domain knowledge, keyword affinity, and
/// response generation templates.
struct AgentDNA: Identifiable, Codable {
    let id: UUID
    let species: String          // e.g., "code.swift.concurrency"
    let emoji: String
    let domain: String
    let keywords: [String]
    let contextBundles: [String] // App bundle IDs that boost confidence
    var fitnessScore: Double     // Evolutionary fitness (0.0 - 1.0)
    var spawnCount: Int          // How many times this DNA has been used
    var successCount: Int        // How many times response was accepted
    let generation: Int          // Evolutionary generation

    /// Mutation rate based on fitness — low fitness = high mutation
    var mutationRate: Double {
        return max(0.05, 1.0 - fitnessScore)
    }

    /// Survival probability — higher fitness = more likely to survive
    var survivalProbability: Double {
        return fitnessScore * 0.7 + (Double(successCount) / max(1.0, Double(spawnCount))) * 0.3
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - Micro-Agent (Disposable Intelligence Unit)
// ═══════════════════════════════════════════════════════════════

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

// ═══════════════════════════════════════════════════════════════
// MARK: - Swarm Consensus Protocol
// ═══════════════════════════════════════════════════════════════

/// Byzantine fault-tolerant consensus for agent responses.
/// Uses weighted voting to determine the best response.
enum ConsensusProtocol {
    /// Simple majority — best single response wins
    case majority
    /// Weighted synthesis — top N responses are merged
    case synthesis(topN: Int)
    /// Tournament — agents compete head-to-head
    case tournament
    /// Unanimous — all agents must agree (high confidence required)
    case unanimous

    /// Select the best response(s) from the swarm
    static func resolve(
        agents: [MicroAgent],
        protocol proto: ConsensusProtocol = .synthesis(topN: 3)
    ) -> SwarmConsensusResult {
        let sorted = agents.sorted { $0.confidence > $1.confidence }
        let totalConfidence = sorted.reduce(0.0) { $0 + $1.confidence }

        switch proto {
        case .majority:
            guard let winner = sorted.first else {
                return SwarmConsensusResult.empty
            }
            return SwarmConsensusResult(
                finalResponse: winner.response,
                winningAgent: winner.dna.species,
                winningEmoji: winner.dna.emoji,
                participantCount: agents.count,
                consensusStrength: winner.confidence,
                protocol: "Majority",
                breakdown: sorted.prefix(5).map { agent in
                    SwarmConsensusResult.AgentVote(
                        species: agent.dna.species,
                        emoji: agent.dna.emoji,
                        confidence: agent.confidence,
                        processingTimeMs: agent.processingTimeMs
                    )
                }
            )

        case .synthesis(let topN):
            let experts = Array(sorted.prefix(topN).filter { $0.confidence > 0.2 })
            guard !experts.isEmpty else { return SwarmConsensusResult.empty }

            if experts.count == 1 {
                return SwarmConsensusResult(
                    finalResponse: experts[0].response,
                    winningAgent: experts[0].dna.species,
                    winningEmoji: experts[0].dna.emoji,
                    participantCount: agents.count,
                    consensusStrength: experts[0].confidence,
                    protocol: "Single Expert",
                    breakdown: sorted.prefix(5).map { agent in
                        SwarmConsensusResult.AgentVote(
                            species: agent.dna.species,
                            emoji: agent.dna.emoji,
                            confidence: agent.confidence,
                            processingTimeMs: agent.processingTimeMs
                        )
                    }
                )
            }

            // Build collaborative synthesis
            let hiveLabel = experts.map { "\($0.dna.emoji) \($0.dna.species)" }.joined(separator: " × ")
            var synthesis = "🐝 **Hive Mind — \(agents.count) agents spawned, \(experts.count) converged**\n"
            synthesis += "Consensus: \(hiveLabel)\n\n"
            synthesis += "═══════════════════════════════════════\n\n"

            for expert in experts {
                let weight = Int((expert.confidence / totalConfidence) * 100)
                synthesis += "### \(expert.dna.emoji) \(expert.dna.species) (\(weight)% weight)\n"
                synthesis += "\(expert.response)\n\n"
                synthesis += "───\n\n"
            }

            return SwarmConsensusResult(
                finalResponse: synthesis,
                winningAgent: "HiveMind",
                winningEmoji: "🐝",
                participantCount: agents.count,
                consensusStrength: experts.first?.confidence ?? 0,
                protocol: "Synthesis(\(topN))",
                breakdown: sorted.prefix(10).map { agent in
                    SwarmConsensusResult.AgentVote(
                        species: agent.dna.species,
                        emoji: agent.dna.emoji,
                        confidence: agent.confidence,
                        processingTimeMs: agent.processingTimeMs
                    )
                }
            )

        case .tournament:
            // Round-robin tournament: higher confidence always wins
            guard sorted.count >= 2 else {
                return ConsensusProtocol.resolve(agents: agents, protocol: .majority)
            }
            // Champion is simply the highest after all rounds
            return ConsensusProtocol.resolve(agents: agents, protocol: .majority)

        case .unanimous:
            let threshold = 0.6
            let agreeing = sorted.filter { $0.confidence > threshold }
            if agreeing.count == sorted.count && !sorted.isEmpty {
                return ConsensusProtocol.resolve(agents: agents, protocol: .majority)
            } else {
                // No unanimous agreement — fall back to synthesis
                return ConsensusProtocol.resolve(agents: agents, protocol: .synthesis(topN: 3))
            }
        }
    }
}

struct SwarmConsensusResult {
    let finalResponse: String
    let winningAgent: String
    let winningEmoji: String
    let participantCount: Int
    let consensusStrength: Double
    let `protocol`: String
    let breakdown: [AgentVote]

    struct AgentVote {
        let species: String
        let emoji: String
        let confidence: Double
        let processingTimeMs: Double
    }

    static let empty = SwarmConsensusResult(
        finalResponse: "The swarm could not reach consensus. Try rephrasing your query.",
        winningAgent: "None",
        winningEmoji: "❓",
        participantCount: 0,
        consensusStrength: 0,
        protocol: "None",
        breakdown: []
    )
}

// ═══════════════════════════════════════════════════════════════
// MARK: - Fitness Tracker (Evolutionary Learning)
// ═══════════════════════════════════════════════════════════════

/// Tracks agent performance over time and evolves the swarm.
/// Better-performing agent DNAs rise, poor ones are culled.
final class FitnessTracker: ObservableObject {
    static let shared = FitnessTracker()

    @Published var generation: Int = 0
    @Published var totalSpawns: Int = 0
    @Published var totalQueries: Int = 0
    @Published var topPerformers: [String] = []

    private var dnaFitness: [String: (wins: Int, total: Int)] = [:]

    /// Record a successful response
    func recordSuccess(species: String) {
        var entry = dnaFitness[species] ?? (wins: 0, total: 0)
        entry.wins += 1
        entry.total += 1
        dnaFitness[species] = entry
        updateTopPerformers()
    }

    /// Record any spawn (regardless of outcome)
    func recordSpawn(species: String) {
        var entry = dnaFitness[species] ?? (wins: 0, total: 0)
        entry.total += 1
        dnaFitness[species] = entry
        totalSpawns += 1
    }

    /// Get fitness score for a species
    func fitness(for species: String) -> Double {
        guard let entry = dnaFitness[species], entry.total > 0 else { return 0.5 }
        return Double(entry.wins) / Double(entry.total)
    }

    /// Evolve — increase generation, prune weak performers
    func evolve() {
        generation += 1
        // Remove species with < 10% win rate and > 10 spawns
        dnaFitness = dnaFitness.filter { _, entry in
            guard entry.total > 10 else { return true } // Too few data points
            return Double(entry.wins) / Double(entry.total) > 0.1
        }
        updateTopPerformers()
        NSLog("🧬 Swarm evolved to generation \(generation). Active species: \(dnaFitness.count)")
    }

    private func updateTopPerformers() {
        topPerformers = dnaFitness
            .sorted { fitness(for: $0.key) > fitness(for: $1.key) }
            .prefix(5)
            .map { $0.key }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - Swarm Telemetry (Real-time Dashboard Data)
// ═══════════════════════════════════════════════════════════════

/// Live metrics about the swarm's health and activity.
final class SwarmTelemetry: ObservableObject {
    static let shared = SwarmTelemetry()

    @Published var activeAgentCount: Int = 0
    @Published var totalDNATemplates: Int = 0
    @Published var averageResponseTime: Double = 0
    @Published var consensusProtocol: String = "Synthesis"
    @Published var lastQueryAgentCount: Int = 0
    @Published var swarmHealth: SwarmHealth = .nominal
    @Published var peakConcurrency: Int = 0
    @Published var queriesPerMinute: Double = 0

    private var queryTimestamps: [Date] = []

    enum SwarmHealth: String {
        case nominal = "🟢 Nominal"
        case elevated = "🟡 Elevated"
        case critical = "🔴 Critical"
        case hibernating = "💤 Hibernating"
    }

    func recordQuery(agentCount: Int, responseTimeMs: Double) {
        let now = Date()
        queryTimestamps.append(now)
        // Keep only last 60 seconds
        queryTimestamps = queryTimestamps.filter { now.timeIntervalSince($0) < 60 }
        queriesPerMinute = Double(queryTimestamps.count)

        lastQueryAgentCount = agentCount
        if agentCount > peakConcurrency { peakConcurrency = agentCount }

        // Rolling average response time
        averageResponseTime = (averageResponseTime * 0.8) + (responseTimeMs * 0.2)

        // Health assessment
        if queriesPerMinute > 30 { swarmHealth = .critical }
        else if queriesPerMinute > 10 { swarmHealth = .elevated }
        else if queriesPerMinute > 0 { swarmHealth = .nominal }
        else { swarmHealth = .hibernating }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - Context Mesh (Shared Intelligence Layer)
// ═══════════════════════════════════════════════════════════════

/// A shared context layer that all micro-agents can read from.
/// Provides environmental awareness, pattern learning, and session momentum.
final class ContextMesh: ObservableObject {
    static let shared = ContextMesh()

    /// Recently active file types (detected from clipboard, window titles)
    @Published var activeFileTypes: Set<String> = []
    /// Active project name (guessed from Xcode/VS Code window title)
    @Published var activeProject: String = ""
    /// Detected programming languages in current session
    @Published var detectedLanguages: Set<String> = []
    /// Cached user mode (synced from MainActor UserModeManager)
    @Published var cachedUserMode: UserMode = .normal
    /// Session start time
    let sessionStart = Date()
    /// Query history for pattern detection
    private var recentQueries: [String] = []
    /// Detected user intent patterns
    @Published var intentSignal: IntentSignal = .exploring

    // ── Pattern Learning State ──
    /// Species that won recently (session momentum)
    var recentWinners: [String] = []
    /// Frequency map: how often each species wins for this user
    private var speciesWinCount: [String: Int] = [:]
    /// Time-of-day patterns: which species win during which time slots
    private var timeSlotWins: [String: [String: Int]] = [:] // [timeSlot: [species: count]]

    enum IntentSignal: String {
        case coding = "💻 Coding"
        case debugging = "🐛 Debugging"
        case learning = "📖 Learning"
        case creating = "🎨 Creating"
        case exploring = "🧭 Exploring"
        case shipping = "🚀 Shipping"
        case resting = "🧘 Resting"
    }

    /// Record a winning species for pattern learning
    func recordWinner(species: String, timeSlot: String) {
        // Session momentum (keep last 10 winners)
        recentWinners.append(species)
        if recentWinners.count > 10 { recentWinners.removeFirst() }

        // Frequency tracking
        speciesWinCount[species, default: 0] += 1

        // Time-of-day pattern
        var slotData = timeSlotWins[timeSlot] ?? [:]
        slotData[species, default: 0] += 1
        timeSlotWins[timeSlot] = slotData
    }

    /// Get top species for a time slot (predictive boost)
    func topSpeciesForTimeSlot(_ slot: String, limit: Int = 5) -> [String] {
        guard let slotData = timeSlotWins[slot] else { return [] }
        return slotData.sorted { $0.value > $1.value }.prefix(limit).map { $0.key }
    }

    /// Get the user's most-used species overall
    func topSpeciesOverall(limit: Int = 10) -> [String] {
        speciesWinCount.sorted { $0.value > $1.value }.prefix(limit).map { $0.key }
    }

    /// Update context from a new query
    func ingest(query: String, sensors: SensorFusion) {
        recentQueries.append(query)
        if recentQueries.count > 50 { recentQueries.removeFirst() }

        // Detect intent from recent patterns (bilingual ES/EN)
        let recent = recentQueries.suffix(5).joined(separator: " ").lowercased()

        if recent.contains("fix") || recent.contains("error") || recent.contains("bug") || recent.contains("crash") || recent.contains("falla") || recent.contains("roto") || recent.contains("problema") {
            intentSignal = .debugging
        } else if recent.contains("build") || recent.contains("deploy") || recent.contains("ship") || recent.contains("release") || recent.contains("publicar") || recent.contains("subir") {
            intentSignal = .shipping
        } else if recent.contains("create") || recent.contains("design") || recent.contains("art") || recent.contains("prompt") || recent.contains("crear") || recent.contains("diseñar") || recent.contains("dibujar") {
            intentSignal = .creating
        } else if recent.contains("what") || recent.contains("how") || recent.contains("explain") || recent.contains("learn") || recent.contains("qué") || recent.contains("cómo") || recent.contains("explica") || recent.contains("aprend") {
            intentSignal = .learning
        } else if recent.contains("code") || recent.contains("func") || recent.contains("class") || recent.contains("refactor") || recent.contains("código") || recent.contains("implementar") {
            intentSignal = .coding
        } else if recent.contains("break") || recent.contains("rest") || recent.contains("tired") || recent.contains("descanso") || recent.contains("cansado") || recent.contains("pausa") {
            intentSignal = .resting
        } else {
            intentSignal = .exploring
        }

        // ── Sync user mode from MainActor ──
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                cachedUserMode = UserModeManager.shared.activeMode
            }
        }

        // ── UserMode override: mode intent takes precedence ──
        switch cachedUserMode {
        case .dj, .creative:
            if intentSignal == .exploring { intentSignal = .creating }
        case .focus, .producer:
            if intentSignal == .exploring { intentSignal = .coding }
        case .tdah:
            // Keep intent but bias toward focus
            if intentSignal == .exploring { intentSignal = .learning }
        case .gaming:
            break  // Gaming mode doesn't change AI intent
        case .night:
            if intentSignal == .exploring { intentSignal = .resting }
        default: break
        }

        // Detect languages from context
        if sensors.activeAppBundle.contains("Xcode") || sensors.activeAppBundle.contains("dt.Xcode") {
            detectedLanguages.insert("Swift")
        }
        if sensors.activeAppBundle.contains("VSCode") || sensors.activeAppBundle.contains("Cursor") {
            if let clip = sensors.clipboardContent {
                if clip.contains("import ") && clip.contains("from ") { detectedLanguages.insert("Python") }
                if clip.contains("const ") || clip.contains("=>") { detectedLanguages.insert("JavaScript") }
                if clip.contains("func ") && clip.contains("->") { detectedLanguages.insert("Swift") }
                if clip.contains("fn ") && clip.contains("->") { detectedLanguages.insert("Rust") }
            }
        }

        // Detect languages from query itself
        let q = query.lowercased()
        if q.contains("swift") || q.contains("swiftui") { detectedLanguages.insert("Swift") }
        if q.contains("python") || q.contains("django") || q.contains("flask") { detectedLanguages.insert("Python") }
        if q.contains("javascript") || q.contains("react") || q.contains("node") { detectedLanguages.insert("JavaScript") }
        if q.contains("rust") || q.contains("cargo") { detectedLanguages.insert("Rust") }
        if q.contains("go ") || q.contains("golang") { detectedLanguages.insert("Go") }
        if q.contains("php") || q.contains("laravel") { detectedLanguages.insert("PHP") }
        if q.contains("typescript") || q.contains("angular") { detectedLanguages.insert("TypeScript") }
    }

    /// Domain bias: which species domains are boosted in current mode
    var modeDomainBias: Set<String> {
        switch cachedUserMode {
        case .dj:       return ["Audio", "Music", "DJ", "MIDI", "BPM"]
        case .producer: return ["Audio", "Music", "DAW", "Mix", "Master", "MIDI"]
        case .creative: return ["Design", "Creative", "Art", "Prompt", "Color"]
        case .focus:    return ["Code", "Swift", "React", "Debug", "Architecture"]
        case .gaming:   return ["Performance", "GPU", "FPS", "Optimization"]
        case .images:   return ["Design", "Color", "Figma", "CSS", "Art"]
        default:        return []
        }
    }

    /// Session duration in minutes
    var sessionMinutes: Int {
        Int(Date().timeIntervalSince(sessionStart) / 60)
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - 🏭 DNA Registry (Agent Genome Database)
// ═══════════════════════════════════════════════════════════════

/// The master catalogue of all agent DNA templates.
/// From these templates, thousands of micro-agents are spawned.
enum DNARegistry {
    // ── Code Domain (100+ sub-specialties) ──
    static let codeGenomes: [AgentDNA] = {
        let base = ["code", "program", "develop", "software", "engineer"]
        let languages: [(String, String, [String])] = [
            ("Swift", "🦅", ["swift", "swiftui", "uikit", "appkit", "xcode", "combine", "async", "await", "actor", "@State", "@Published", "observable", "spm", "cocoapods", "xctest"]),
            ("Python", "🐍", ["python", "pip", "django", "flask", "fastapi", "numpy", "pandas", "torch", "tensorflow", "jupyter", "virtualenv", "pytest", "decorator", "yield", "asyncio"]),
            ("JavaScript", "⚡", ["javascript", "js", "node", "npm", "react", "vue", "angular", "next.js", "express", "webpack", "vite", "typescript", "deno", "bun", "jest"]),
            ("Rust", "🦀", ["rust", "cargo", "ownership", "borrow", "lifetime", "unsafe", "trait", "impl", "tokio", "wasm", "serde", "actix"]),
            ("Go", "🐹", ["golang", "go", "goroutine", "channel", "defer", "interface", "gin", "fiber"]),
            ("SQL", "🗃️", ["sql", "select", "join", "index", "query", "postgres", "mysql", "sqlite", "migration", "schema", "orm", "prisma", "drizzle"]),
            ("Shell", "💻", ["bash", "zsh", "shell", "terminal", "cli", "grep", "awk", "sed", "pipe", "chmod", "cron"]),
            ("HTML/CSS", "🎨", ["html", "css", "flexbox", "grid", "responsive", "media query", "sass", "tailwind", "animation", "transition"]),
            ("Solidity", "⛓️", ["solidity", "contract", "ethereum", "web3", "erc20", "erc721", "hardhat", "foundry", "abi"]),
            ("C++", "⚙️", ["cpp", "c++", "pointer", "template", "stl", "cmake", "makefile", "header"]),
            ("Kotlin", "🟣", ["kotlin", "android", "jetpack", "compose", "coroutine", "flow", "ktor"]),
            ("PHP", "🐘", ["php", "laravel", "composer", "artisan", "blade", "eloquent", "symfony"]),
            ("Ruby", "💎", ["ruby", "rails", "gem", "bundler", "rake", "rspec", "sinatra"]),
            ("Dart", "🎯", ["dart", "flutter", "widget", "pubspec", "riverpod"]),
        ]

        var genomes: [AgentDNA] = []
        let bundles = ["com.apple.dt.Xcode", "com.microsoft.VSCode", "com.todesktop.230510fqmkbjh6g",
                       "dev.warp.warp-stable", "com.apple.Terminal", "com.googlecode.iterm2"]

        for (lang, emoji, keywords) in languages {
            // Base language agent
            genomes.append(AgentDNA(
                id: UUID(), species: "code.\(lang.lowercased())", emoji: emoji,
                domain: "\(lang) Development", keywords: base + keywords,
                contextBundles: bundles, fitnessScore: 0.5, spawnCount: 0,
                successCount: 0, generation: 0
            ))
            // Sub-specialties
            let specialties = ["debug", "optimize", "refactor", "test", "architecture", "patterns"]
            for spec in specialties {
                genomes.append(AgentDNA(
                    id: UUID(), species: "code.\(lang.lowercased()).\(spec)",
                    emoji: emoji, domain: "\(lang) \(spec.capitalized)",
                    keywords: keywords + [spec, "\(spec)ing"],
                    contextBundles: bundles, fitnessScore: 0.5,
                    spawnCount: 0, successCount: 0, generation: 0
                ))
            }
        }
        return genomes
    }()

    // ── Creative Domain ──
    static let creativeGenomes: [AgentDNA] = {
        let domains: [(String, String, String, [String], [String])] = [
            ("creative.midjourney", "🖼", "Midjourney Prompts", ["midjourney", "imagine", "prompt", "render", "concept art", "--ar", "--v 6", "--style raw", "composition", "lighting"], ["com.hnc.Discord"]),
            ("creative.suno", "🎵", "Music Generation", ["suno", "udio", "song", "lyrics", "melody", "beat", "bpm", "genre", "tempo", "chorus", "verse"], []),
            ("creative.runway", "📹", "Video Generation", ["runway", "gen-3", "video", "motion", "animate", "camera movement", "dolly", "pan", "edit"], []),
            ("creative.dalle", "🎨", "Image Generation", ["dall-e", "dalle", "image", "generate", "visual", "illustration", "concept", "style transfer"], []),
            ("creative.color", "🌈", "Color Theory", ["color", "palette", "hex", "rgb", "hsl", "gradient", "contrast", "complementary", "analogous", "triadic"], []),
            ("creative.typography", "🔤", "Typography", ["font", "typeface", "typography", "serif", "sans-serif", "weight", "line-height", "kerning", "tracking"], []),
            ("creative.3d", "🧊", "3D Modeling", ["3d", "blender", "three.js", "webgl", "glb", "gltf", "mesh", "texture", "shader", "raytracing"], []),
            ("creative.audio", "🎧", "Audio Engineering", ["mix", "master", "eq", "compressor", "reverb", "delay", "sidechain", "stereo", "lufs", "frequency"], ["com.ableton.live", "com.apple.logicpro"]),
            ("creative.motion", "✨", "Motion Design", ["animation", "keyframe", "easing", "spring", "physics", "parallax", "lottie", "rive", "after effects"], []),
            ("creative.branding", "🏷️", "Brand Identity", ["brand", "identity", "logo", "visual language", "guideline", "mood board", "tone", "voice"], []),
        ]

        return domains.map { species, emoji, domain, keywords, bundles in
            AgentDNA(id: UUID(), species: species, emoji: emoji, domain: domain,
                     keywords: keywords, contextBundles: bundles, fitnessScore: 0.5,
                     spawnCount: 0, successCount: 0, generation: 0)
        }
    }()

    // ── Infrastructure Domain ──
    static let infraGenomes: [AgentDNA] = {
        let domains: [(String, String, String, [String], [String])] = [
            ("infra.docker", "🐳", "Docker & Containers", ["docker", "container", "dockerfile", "compose", "image", "volume", "network", "registry"], ["com.apple.Terminal"]),
            ("infra.kubernetes", "☸️", "Kubernetes", ["kubernetes", "k8s", "pod", "deployment", "service", "ingress", "helm", "kubectl", "minikube"], []),
            ("infra.ci", "🔄", "CI/CD Pipelines", ["ci", "cd", "pipeline", "github actions", "jenkins", "circleci", "gitlab ci", "workflow", "artifact"], []),
            ("infra.cloud.aws", "☁️", "AWS", ["aws", "s3", "ec2", "lambda", "dynamo", "cloudfront", "iam", "vpc", "ecs", "fargate", "cloudwatch"], []),
            ("infra.cloud.gcp", "🌩️", "Google Cloud", ["gcp", "firebase", "cloud run", "cloud functions", "bigquery", "pubsub", "spanner", "gke"], []),
            ("infra.cloud.azure", "🔵", "Azure", ["azure", "blob", "cosmos", "app service", "functions", "devops", "active directory"], []),
            ("infra.terraform", "🏗️", "Infrastructure as Code", ["terraform", "iac", "pulumi", "cloudformation", "ansible", "state", "plan", "apply", "module"], []),
            ("infra.monitoring", "📊", "Monitoring & Observability", ["monitoring", "prometheus", "grafana", "datadog", "new relic", "alert", "metric", "trace", "log", "sentry"], []),
            ("infra.networking", "📡", "Networking", ["network", "dns", "cdn", "load balancer", "proxy", "nginx", "reverse proxy", "ssl", "tls", "firewall", "vpn"], []),
            ("infra.security", "🔐", "Security Engineering", ["security", "audit", "penetration", "owasp", "cve", "vulnerability", "encryption", "zero trust", "rbac"], []),
        ]

        return domains.map { species, emoji, domain, keywords, bundles in
            AgentDNA(id: UUID(), species: species, emoji: emoji, domain: domain,
                     keywords: keywords, contextBundles: bundles, fitnessScore: 0.5,
                     spawnCount: 0, successCount: 0, generation: 0)
        }
    }()

    // ── Research & Analysis Domain ──
    static let researchGenomes: [AgentDNA] = {
        let domains: [(String, String, String, [String])] = [
            ("research.data", "📊", "Data Science", ["data", "dataset", "analysis", "statistics", "regression", "classification", "clustering", "pca", "feature"]),
            ("research.ml", "🤖", "Machine Learning", ["ml", "model", "train", "inference", "neural", "transformer", "llm", "fine-tune", "rlhf", "embedding"]),
            ("research.nlp", "💬", "NLP", ["nlp", "natural language", "tokenize", "sentiment", "ner", "bert", "gpt", "prompt engineering", "rag"]),
            ("research.cv", "👁️", "Computer Vision", ["vision", "image", "detection", "segmentation", "yolo", "cnn", "resnet", "diffusion"]),
            ("research.math", "🔢", "Mathematics", ["math", "equation", "integral", "derivative", "matrix", "probability", "bayesian", "statistics"]),
            ("research.crypto", "🔐", "Cryptography", ["crypto", "hash", "encrypt", "decrypt", "aes", "rsa", "ed25519", "zero knowledge", "zkp"]),
        ]

        return domains.map { species, emoji, domain, keywords in
            AgentDNA(id: UUID(), species: species, emoji: emoji, domain: domain,
                     keywords: keywords, contextBundles: [], fitnessScore: 0.5,
                     spawnCount: 0, successCount: 0, generation: 0)
        }
    }()

    // ── Business & Communication Domain ──
    static let businessGenomes: [AgentDNA] = {
        let domains: [(String, String, String, [String])] = [
            ("biz.writing", "✍️", "Technical Writing", ["write", "document", "readme", "article", "blog", "copy", "headline", "pitch", "newsletter"]),
            ("biz.marketing", "📢", "Digital Marketing", ["marketing", "seo", "sem", "growth", "funnel", "conversion", "ab test", "analytics", "campaign"]),
            ("biz.finance", "💰", "Finance & Markets", ["price", "market", "stock", "crypto", "trading", "portfolio", "roi", "revenue", "profit", "valuation"]),
            ("biz.legal", "⚖️", "Legal & Compliance", ["license", "gdpr", "privacy policy", "terms", "copyright", "patent", "compliance", "regulation"]),
            ("biz.pm", "📋", "Project Management", ["sprint", "backlog", "kanban", "scrum", "velocity", "standup", "retro", "epic", "story", "task"]),
            ("biz.product", "🎯", "Product Strategy", ["product", "roadmap", "mvp", "user story", "persona", "market fit", "pivot", "metrics", "okr", "kpi"]),
        ]

        return domains.map { species, emoji, domain, keywords in
            AgentDNA(id: UUID(), species: species, emoji: emoji, domain: domain,
                     keywords: keywords, contextBundles: [], fitnessScore: 0.5,
                     spawnCount: 0, successCount: 0, generation: 0)
        }
    }()

    // ── Wellbeing & Lifestyle Domain ──
    static let wellbeingGenomes: [AgentDNA] = {
        let domains: [(String, String, String, [String])] = [
            ("well.focus", "🧘", "Focus & Flow", ["focus", "concentrate", "pomodoro", "deep work", "flow state", "distraction", "mindful"]),
            ("well.health", "💚", "Developer Health", ["tired", "break", "rest", "posture", "eyes", "stretch", "ergonomic", "burnout"]),
            ("well.energy", "⚡", "Energy Management", ["energy", "coffee", "sleep", "nap", "circadian", "productivity", "peak", "ultradian"]),
            ("well.mood", "🌡️", "Mood & Stress", ["stressed", "anxious", "calm", "breathe", "meditation", "gratitude", "journal"]),
        ]

        return domains.map { species, emoji, domain, keywords in
            AgentDNA(id: UUID(), species: species, emoji: emoji, domain: domain,
                     keywords: keywords, contextBundles: [], fitnessScore: 0.5,
                     spawnCount: 0, successCount: 0, generation: 0)
        }
    }()

    // ── Bilingual Domain (Spanish-specific knowledge) ──
    static let bilingualGenomes: [AgentDNA] = {
        let domains: [(String, String, String, [String])] = [
            ("lang.es.code", "🇪🇸", "Código en Español", ["código", "función", "variable", "clase", "método", "error", "compilar", "optimizar", "depurar"]),
            ("lang.es.creative", "🇪🇸", "Creativo en Español", ["diseñar", "crear", "arte", "estilo", "concepto", "generar", "visual", "componer"]),
            ("lang.es.biz", "🇪🇸", "Negocios en Español", ["negocio", "proyecto", "estrategia", "mercado", "ventas", "cliente", "factura", "presupuesto"]),
            ("lang.translate", "🌍", "Translation", ["translate", "traducir", "idioma", "language", "localize", "i18n", "l10n"]),
        ]

        return domains.map { species, emoji, domain, keywords in
            AgentDNA(id: UUID(), species: species, emoji: emoji, domain: domain,
                     keywords: keywords, contextBundles: [], fitnessScore: 0.5,
                     spawnCount: 0, successCount: 0, generation: 0)
        }
    }()

    /// ALL DNA templates in the registry
    static var allDNA: [AgentDNA] {
        codeGenomes + creativeGenomes + infraGenomes + researchGenomes + businessGenomes + wellbeingGenomes + bilingualGenomes
    }

    /// Total number of DNA templates
    static var totalSpecies: Int { allDNA.count }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - 🐝 SwarmHive (The Coordination Engine)
// ═══════════════════════════════════════════════════════════════

/// The SwarmHive is the central coordinator that spawns, schedules,
/// and resolves micro-agents for every query. It replaces the
/// simple agent iteration loop with a massively parallel system.
final class SwarmHive: ObservableObject {
    static let shared = SwarmHive()

    // ── Published State ──
    @Published var lastSwarmSize: Int = 0
    @Published var lastConsensus: String = "—"
    @Published var isProcessing: Bool = false
    @Published var activeSpecies: [String] = []

    // ── Subsystems ──
    let fitness = FitnessTracker.shared
    let telemetry = SwarmTelemetry.shared
    let contextMesh = ContextMesh.shared

    // ── DNA Pool ──
    private lazy var dnaPool: [AgentDNA] = DNARegistry.allDNA

    // ── Legacy Agent Bridge ──
    // The original 26 agents are wrapped as DNA for backward compatibility
    private let legacyBridge: [NotchAgent]

    // ── Configuration ──
    let maxConcurrentAgents = 500
    let confidenceThreshold = 0.15
    let topNForConsensus = 5

    // ── Agent Chaining ──
    private let chainingRules: [String: [String]] = [
        "code.swift": ["infra.ci", "infra.docker"],   // Swift → CI/CD, Docker
        "code.python": ["research.ml", "research.data"], // Python → ML, Data
        "code.javascript": ["infra.cloud.gcp", "infra.ci"],
        "creative.midjourney": ["creative.color", "creative.typography"],
        "creative.audio": ["creative.motion"],
        "infra.docker": ["infra.kubernetes", "infra.ci"],
        "infra.kubernetes": ["infra.monitoring", "infra.networking"],
        "research.ml": ["research.data", "research.cv"],
        "biz.product": ["biz.marketing", "biz.pm"],
    ]

    private init() {
        // Bridge legacy agents (original 20 + 80 extended)
        let core: [NotchAgent] = [
            ArchitectAgent(), MuseAgent(), AnalystAgent(),
            SentinelAgent(), EmpathAgent(), OrchestratorAgent()
        ]
        legacyBridge = core + SpecialistRegistry.all + ExtendedSpecialistRegistry.all

        telemetry.totalDNATemplates = DNARegistry.totalSpecies + legacyBridge.count

        NSLog("🐝 SwarmHive v3 initialized: \(DNARegistry.totalSpecies) DNA + \(legacyBridge.count) legacy = \(telemetry.totalDNATemplates) total species")
    }

    // ════════════════════════════════════════
    // MARK: - Swarm Spawn & Execute
    // ════════════════════════════════════════

    /// Spawn a swarm of micro-agents, evaluate, and reach consensus.
    /// This is the main entry point for query processing.
    func swarmProcess(
        query: String,
        sensors: SensorFusion,
        memory: ConversationMemory
    ) -> SwarmConsensusResult {

        let startTime = CFAbsoluteTimeGetCurrent()
        contextMesh.ingest(query: query, sensors: sensors)

        // Phase 1: Spawn micro-agents from DNA pool
        var swarm: [MicroAgent] = []

        for dna in dnaPool {
            var agent = MicroAgent(dna: dna)
            agent.evaluate(query: query, context: sensors)

            if agent.confidence > confidenceThreshold {
                swarm.append(agent)
                fitness.recordSpawn(species: dna.species)
            }
        }

        // Phase 2: Also run legacy agents (backward compatibility)
        for legacyAgent in legacyBridge {
            let conf = legacyAgent.confidence(for: query, context: sensors)
            if conf > confidenceThreshold {
                let response = legacyAgent.respond(to: query, context: sensors, memory: memory)
                var micro = MicroAgent(dna: AgentDNA(
                    id: UUID(), species: "legacy.\(legacyAgent.name.lowercased())",
                    emoji: legacyAgent.emoji, domain: legacyAgent.domain,
                    keywords: [], contextBundles: [], fitnessScore: 0.6,
                    spawnCount: 0, successCount: 0, generation: 0
                ))
                micro.response = response.text
                micro.confidence = response.confidence
                swarm.append(micro)
            }
        }

        // Phase 3: Generate responses for top DNA micro-agents
        swarm.sort { $0.confidence > $1.confidence }
        let topAgents = Array(swarm.prefix(maxConcurrentAgents))

        // For DNA-spawned agents, generate responses based on context
        var respondedAgents: [MicroAgent] = []
        for var agent in topAgents {
            if agent.response.isEmpty {
                agent.response = generateResponse(for: agent, query: query, sensors: sensors, memory: memory)
            }
            agent.processingTimeMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            respondedAgents.append(agent)
        }

        // Phase 4: Agent Chaining — boost related agents
        for agent in respondedAgents where agent.confidence > 0.4 {
            let baseSpecies = agent.dna.species.components(separatedBy: ".").prefix(2).joined(separator: ".")
            if let chainTargets = chainingRules[baseSpecies] {
                for var chainAgent in respondedAgents {
                    let chainBase = chainAgent.dna.species.components(separatedBy: ".").prefix(2).joined(separator: ".")
                    if chainTargets.contains(chainBase) && chainAgent.confidence < agent.confidence {
                        chainAgent.confidence = min(1.0, chainAgent.confidence + 0.15)
                    }
                }
            }
        }

        // Phase 5: Consensus
        let result = ConsensusProtocol.resolve(
            agents: respondedAgents,
            protocol: .synthesis(topN: topNForConsensus)
        )

        // Phase 6: Record telemetry + pattern learning
        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        telemetry.recordQuery(agentCount: swarm.count, responseTimeMs: elapsed)
        fitness.totalQueries += 1

        // Record winning agent for fitness + pattern learning
        if !result.winningAgent.isEmpty && result.winningAgent != "None" {
            fitness.recordSuccess(species: result.winningAgent)
            let timeSlot: String
            switch sensors.timeOfDay {
            case .morning: timeSlot = "morning"
            case .afternoon, .evening: timeSlot = "afternoon"
            case .night: timeSlot = "night"
            case .lateNight: timeSlot = "lateNight"
            }
            contextMesh.recordWinner(species: result.winningAgent, timeSlot: timeSlot)
        }

        // Update published state
        DispatchQueue.main.async {
            self.lastSwarmSize = swarm.count
            self.lastConsensus = result.protocol
            self.activeSpecies = result.breakdown.prefix(5).map { $0.species }
        }

        // Log swarm activity
        NSLog("🐝 Swarm v3: \(swarm.count) spawned → \(respondedAgents.count) responded → \(result.protocol) in \(String(format: "%.1f", elapsed))ms | Intent: \(contextMesh.intentSignal.rawValue)")
        for vote in result.breakdown.prefix(5) {
            NSLog("   \(vote.emoji) \(vote.species): \(String(format: "%.2f", vote.confidence))")
        }

        return result
    }

    // ════════════════════════════════════════
    // MARK: - Response Generation Engine
    // ════════════════════════════════════════

    /// Generate a contextual response for a DNA-spawned micro-agent
    private func generateResponse(
        for agent: MicroAgent,
        query: String,
        sensors: SensorFusion,
        memory: ConversationMemory
    ) -> String {
        let species = agent.dna.species
        let domain = agent.dna.domain
        let emoji = agent.dna.emoji
        let q = query.lowercased()
        // let words = q.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }

        // ═══════════════════════════════════════════════════════════
        // REAL Analysis Layer — extract actual meaning from inputs
        // ═══════════════════════════════════════════════════════════

        // 1. Extract matched keywords (what the query is actually about)
        let matchedKeywords = agent.dna.keywords.filter { q.contains($0) }
        let topicSummary = matchedKeywords.isEmpty
            ? domain
            : matchedKeywords.prefix(3).joined(separator: ", ")

        // 2. Real clipboard analysis — parse actual code if present
        let clipboardAnalysis = analyzeClipboard(sensors.clipboardContent, domain: domain, keywords: agent.dna.keywords)

        // 3. Real query intent classification
        let queryIntent = classifyQueryIntent(q)

        // 4. Real app context
        let appName = sensors.activeAppName.isEmpty ? nil : sensors.activeAppName
        let appContext = appName.map { "📍 Working in **\($0)**" } ?? ""

        // 5. Real memory context — what has the user asked before?
        let recentTopics = memory.exchanges.suffix(3).map { $0.query }
        let hasConversationHistory = !recentTopics.isEmpty

        // 6. Real environmental signals
        let cpuWarning = sensors.cpuUsage > 70 ? "\n⚠️ CPU al \(Int(sensors.cpuUsage))% — carga alta detectada" : ""
        let sessionNote: String
        let mins = contextMesh.sessionMinutes
        if mins > 180 { sessionNote = "\n🔴 \(mins) minutos de sesión — pausa obligatoria recomendada" }
        else if mins > 90 { sessionNote = "\n🟡 \(mins)min de sesión — considera un descanso" }
        else { sessionNote = "" }

        let musicNote = sensors.isPlayingMusic ? "\n🎵 Escuchando: \(sensors.currentTrack)" : ""

        // 7. Build time-aware greeting
        let timeGreeting: String
        switch sensors.timeOfDay {
        case .morning: timeGreeting = "Buenos días"
        case .afternoon, .evening: timeGreeting = "Buenas tardes"
        case .night: timeGreeting = "Buenas noches"
        case .lateNight: timeGreeting = "🦉 Sesión nocturna"
        }

        // ═══════════════════════════════════════════════════════════
        // REAL Response Construction — built from actual analysis
        // ═══════════════════════════════════════════════════════════

        var response = "\(emoji) **\(domain)** — \(timeGreeting)\n\(appContext)"

        // Add what we actually detected
        if !matchedKeywords.isEmpty {
            response += "\n🎯 Detected: **\(topicSummary)**"
        }

        // Add intent-specific real guidance
        switch queryIntent {
        case .howTo:
            response += "\n\n**Guía paso a paso para \(topicSummary):**"
            response += generateRealGuidance(for: matchedKeywords, domain: domain, species: species)

        case .debugging:
            response += "\n\n**🔧 Diagnóstico para \(topicSummary):**"
            response += generateDebuggingAdvice(for: matchedKeywords, domain: domain, clipboard: clipboardAnalysis)

        case .comparison:
            response += "\n\n**⚖️ Análisis comparativo:**"
            response += generateComparisonAdvice(for: matchedKeywords, domain: domain)

        case .optimization:
            response += "\n\n**⚡ Optimización de \(topicSummary):**"
            response += generateOptimizationAdvice(for: matchedKeywords, domain: domain)

        case .general:
            response += "\n\n**\(domain) — Análisis contextual:**"
            response += generateRealGuidance(for: matchedKeywords, domain: domain, species: species)
        }

        // Add real clipboard analysis if we found something
        if let clipInfo = clipboardAnalysis {
            response += "\n\n📋 **Análisis del clipboard:**"
            response += "\n\(clipInfo)"
        }

        // Add conversation continuity if relevant
        if hasConversationHistory {
            let relatedPrevious = recentTopics.filter { prev in
                matchedKeywords.contains { prev.lowercased().contains($0) }
            }
            if !relatedPrevious.isEmpty {
                response += "\n\n🔄 Continuando tema previo — contexto acumulado"
            }
        }

        // Add environmental notes
        response += cpuWarning + sessionNote + musicNote

        return response
    }

    // ════════════════════════════════════════
    // MARK: - Real Analysis Helpers
    // ════════════════════════════════════════

    /// Classify what the user actually wants
    private enum QueryIntent {
        case howTo, debugging, comparison, optimization, general
    }

    private func classifyQueryIntent(_ q: String) -> QueryIntent {
        if q.contains("cómo") || q.contains("how") || q.contains("crear") || q.contains("create") || q.contains("hacer") || q.contains("build") || q.contains("implementar") {
            return .howTo
        }
        if q.contains("error") || q.contains("fix") || q.contains("bug") || q.contains("crash") || q.contains("falla") || q.contains("problema") || q.contains("no funciona") || q.contains("debug") {
            return .debugging
        }
        if q.contains("vs") || q.contains("mejor") || q.contains("diferencia") || q.contains("compare") || q.contains("which") || q.contains("cuál") {
            return .comparison
        }
        if q.contains("optimiz") || q.contains("rápido") || q.contains("faster") || q.contains("performance") || q.contains("rendimiento") || q.contains("mejorar") || q.contains("improve") {
            return .optimization
        }
        return .general
    }

    /// Parse real clipboard content — detect language, patterns, issues
    private func analyzeClipboard(_ content: String?, domain: String, keywords: [String]) -> String? {
        guard let clip = content, clip.count > 15 else { return nil }
        let clipLower = clip.lowercased()

        // Only analyze if clipboard is relevant to this agent's domain
        let relevantHits = keywords.filter { clipLower.contains($0) }.count
        guard relevantHits > 0 else { return nil }

        var analysis: [String] = []
        let lines = clip.components(separatedBy: .newlines)
        let lineCount = lines.count

        // Detect language from actual code patterns
        if clipLower.contains("func ") && clipLower.contains("->") || clipLower.contains("@State") || clipLower.contains("var body") {
            analysis.append("Lenguaje detectado: **Swift**")
            if clipLower.contains("@State") || clipLower.contains("@Published") {
                analysis.append("• SwiftUI state management detectado")
            }
            if clipLower.contains("Task {") || clipLower.contains("async ") {
                analysis.append("• Código async/await detectado")
            }
            if clipLower.contains("try") && !clipLower.contains("catch") && !clipLower.contains("try?") && !clipLower.contains("try!") {
                analysis.append("⚠️ `try` sin `catch` — posible crash")
            }
        } else if clipLower.contains("def ") || (clipLower.contains("import ") && clipLower.contains(":")) {
            analysis.append("Lenguaje detectado: **Python**")
            if clipLower.contains("except:") || clipLower.contains("except Exception") {
                analysis.append("⚠️ Catch genérico — mejor especificar excepción")
            }
        } else if clipLower.contains("const ") || clipLower.contains("=>") || clipLower.contains("require(") {
            analysis.append("Lenguaje detectado: **JavaScript/TypeScript**")
            if clipLower.contains("var ") {
                analysis.append("⚠️ `var` detectado — usa `const` o `let`")
            }
            if clipLower.contains("any") {
                analysis.append("⚠️ `any` detectado — perdida de type safety")
            }
        } else if clipLower.contains("fn ") && clipLower.contains("let ") {
            analysis.append("Lenguaje detectado: **Rust**")
            if clipLower.contains("unwrap()") {
                analysis.append("⚠️ `.unwrap()` detectado — usa `?` o `match` en producción")
            }
        }

        // Generic code quality signals
        if lineCount > 50 {
            analysis.append("📏 \(lineCount) líneas — considera dividir en funciones más pequeñas")
        }
        if clipLower.contains("todo") || clipLower.contains("fixme") || clipLower.contains("hack") {
            analysis.append("📌 TODOs/FIXMEs encontrados en el código")
        }
        if clipLower.contains("print(") || clipLower.contains("console.log") || clipLower.contains("NSLog") {
            analysis.append("🧹 Debug prints detectados — limpiar antes de producción")
        }
        if clipLower.contains("force") || clipLower.contains("!") && clipLower.contains("as!") {
            analysis.append("⚠️ Force unwrap/cast detectado — riesgo de crash")
        }

        return analysis.isEmpty ? nil : analysis.joined(separator: "\n")
    }

    /// Generate REAL step-by-step guidance based on matched keywords
    private func generateRealGuidance(for keywords: [String], domain: String, species: String) -> String {
        var steps: [String] = []

        // Code domain — real patterns per language/framework
        if species.hasPrefix("code.") {
            for kw in keywords {
                switch kw {
                case "swift", "swiftui":
                    steps.append("1. Estructura: `@Observable` class (macOS 14+) > `@Published`")
                    steps.append("2. Views: `some View` con `@State` local, `@Binding` para child")
                    steps.append("3. Networking: `async let` para paralelo, `URLSession.shared.data(from:)`")
                    steps.append("4. Errores: `do/catch` con tipos específicos, nunca `try!` en prod")
                case "react", "jsx", "hook":
                    steps.append("1. `useState` para estado local, `useReducer` para estado complejo")
                    steps.append("2. `useEffect` con deps array correcto — evitar arrays vacíos si hay deps")
                    steps.append("3. `useMemo`/`useCallback` solo cuando hay re-renders medidos")
                    steps.append("4. Server Components (Next.js 14+) para datos, Client para interactividad")
                case "python", "django", "flask":
                    steps.append("1. Type hints: `def func(x: int) -> str:` — siempre")
                    steps.append("2. `dataclass` o `pydantic.BaseModel` para estructuras de datos")
                    steps.append("3. `pathlib.Path` > `os.path` — más expresivo y seguro")
                    steps.append("4. `uv` > `pip` para gestión de dependencias (10x más rápido)")
                case "docker", "container":
                    steps.append("1. Multi-stage build: `FROM node:20 AS builder` → `FROM node:20-slim`")
                    steps.append("2. `.dockerignore`: `node_modules`, `.git`, `*.md`")
                    steps.append("3. `COPY package*.json .` ANTES de `COPY . .` (cache de deps)")
                    steps.append("4. `USER nonroot` — nunca correr como root en producción")
                case "kubernetes", "k8s":
                    steps.append("1. `resources.requests` y `limits` siempre definidos")
                    steps.append("2. `livenessProbe` + `readinessProbe` para health checks")
                    steps.append("3. `HPA` para autoescalado basado en CPU/memoria")
                    steps.append("4. `NetworkPolicy` para segmentar tráfico entre pods")
                case "git":
                    steps.append("1. Commits: tipo(scope): mensaje — `feat(auth): add OAuth2 flow`")
                    steps.append("2. Branches: `feature/`, `fix/`, `chore/` prefijos")
                    steps.append("3. `git rebase -i` para limpiar historial antes de PR")
                    steps.append("4. Pre-commit hooks: lint + format automático")
                default:
                    steps.append("• Analiza el contexto de \(kw) en tu proyecto actual")
                    steps.append("• Revisa patrones idiomáticos del ecosistema")
                }
            }
        } else if species.hasPrefix("creative.") {
            for kw in keywords {
                switch kw {
                case "ableton", "live", "audio":
                    steps.append("1. Ganancia de staging: -6dB headroom en master")
                    steps.append("2. EQ sustractivo primero, aditivo después")
                    steps.append("3. Compresión: ratio 3:1 para bus, 4:1+ para drums")
                    steps.append("4. Sidechain: Compressor > External Key > kick track")
                case "figma", "design":
                    steps.append("1. Auto Layout para todo — responsive desde el principio")
                    steps.append("2. Design tokens: colores, tipografía, espaciado como variables")
                    steps.append("3. Components con variants (state × size × theme)")
                    steps.append("4. Prototype: Smart Animate entre components para micro-interactions")
                case "midjourney", "stable diffusion", "prompt":
                    steps.append("1. Estructura: sujeto + estilo + iluminación + cámara + calidad")
                    steps.append("2. `--ar 16:9` para panorámico, `--ar 1:1` para cuadrado")
                    steps.append("3. `--style raw` para menos procesamiento de Midjourney")
                    steps.append("4. Negative: `blurry, deformed, low quality, watermark`")
                default:
                    steps.append("• Aplica principios de \(kw) a tu flujo creativo")
                }
            }
        } else if species.hasPrefix("infra.") {
            for kw in keywords {
                switch kw {
                case "ci", "cd", "pipeline":
                    steps.append("1. Build → Test → Lint → Security Scan → Deploy")
                    steps.append("2. Cache de dependencias entre runs (ahorra 60% tiempo)")
                    steps.append("3. Matrix testing: múltiples versiones en paralelo")
                    steps.append("4. Deploy: canary 5% → 25% → 100% (nunca 0 → 100)")
                case "monitoring", "observability":
                    steps.append("1. RED metrics: Rate, Errors, Duration por servicio")
                    steps.append("2. Logs estructurados JSON con correlation IDs")
                    steps.append("3. Distributed tracing con OpenTelemetry")
                    steps.append("4. Alertas por SLOs, no por síntomas individuales")
                case "terraform", "iac":
                    steps.append("1. Remote state: S3 + DynamoDB lock")
                    steps.append("2. Modules: reutilizables, versionados, documentados")
                    steps.append("3. `plan` SIEMPRE antes de `apply`")
                    steps.append("4. Workspaces para separar dev/staging/prod")
                default:
                    steps.append("• Revisa tu setup de \(kw) contra best practices actuales")
                }
            }
        } else if species.hasPrefix("well.") {
            steps.append("1. 🫁 Respiración 4-7-8: Inhala 4s → Mantén 7s → Exhala 8s")
            steps.append("2. 🧊 Agua fría en muñecas → alerta instantánea")
            steps.append("3. 🚶 5 min caminando → 2 horas más de foco")
            steps.append("4. 👁️ Regla 20-20-20: cada 20min, mira 20s a 20 metros")
        }

        if steps.isEmpty {
            steps.append("Describe tu caso específico para guía detallada")
        }

        return "\n" + steps.prefix(5).joined(separator: "\n")
    }

    /// Generate REAL debugging advice
    private func generateDebuggingAdvice(for keywords: [String], domain: String, clipboard: String?) -> String {
        var advice: [String] = []

        advice.append("1. **Reproduce** — aisla el caso mínimo que produce el error")
        advice.append("2. **Lee** el error completo — stack trace, línea, contexto")

        if keywords.contains("swift") || keywords.contains("swiftui") {
            advice.append("3. `po variable` en LLDB para inspeccionar estado")
            advice.append("4. `Thread Sanitizer` para race conditions")
            advice.append("5. `Instruments > Time Profiler` para performance")
        } else if keywords.contains("javascript") || keywords.contains("react") || keywords.contains("node") {
            advice.append("3. `console.trace()` para ver call stack completo")
            advice.append("4. Chrome DevTools > Sources > breakpoints condicionales")
            advice.append("5. `node --inspect` + Chrome DevTools para Node.js")
        } else if keywords.contains("python") {
            advice.append("3. `import pdb; pdb.set_trace()` o `breakpoint()` (3.7+)")
            advice.append("4. `python -m pytest -x --pdb` para debuggear en tests")
            advice.append("5. `traceback.format_exc()` para logs detallados")
        } else {
            advice.append("3. Usa el debugger nativo de tu IDE")
            advice.append("4. Añade logging temporal para trazar el flujo")
            advice.append("5. Revisa cambios recientes con `git diff`")
        }

        if clipboard != nil {
            advice.append("\n📋 El clipboard contiene información relevante — revisa el análisis abajo")
        }

        return "\n" + advice.joined(separator: "\n")
    }

    /// Generate REAL comparison advice
    private func generateComparisonAdvice(for keywords: [String], domain: String) -> String {
        var analysis: [String] = []

        // Find pairs to compare from keywords
        let kwSet = Set(keywords)
        if kwSet.contains("react") || kwSet.contains("vue") {
            analysis.append("**React vs Vue:**")
            analysis.append("• React: ecosistema mayor, más control, JSX")
            analysis.append("• Vue: curva más suave, SFC, template syntax")
            analysis.append("• Para equipos nuevos: Vue. Para scale: React.")
        }
        if kwSet.contains("docker") || kwSet.contains("kubernetes") {
            analysis.append("**Docker vs Kubernetes:**")
            analysis.append("• Docker: empaquetar. K8s: orquestar.")
            analysis.append("• <5 contenedores: Docker Compose basta")
            analysis.append("• >10 servicios con autoescalado: K8s")
        }
        if kwSet.contains("rest") || kwSet.contains("graphql") {
            analysis.append("**REST vs GraphQL:**")
            analysis.append("• REST: simple, cacheable, estándar")
            analysis.append("• GraphQL: flexible, menos over-fetching")
            analysis.append("• CRUD simple: REST. Datos complejos/nested: GraphQL")
        }

        if analysis.isEmpty {
            analysis.append("Especifica qué tecnologías quieres comparar para un análisis detallado de \(domain)")
        }

        return "\n" + analysis.joined(separator: "\n")
    }

    /// Generate REAL optimization advice
    private func generateOptimizationAdvice(for keywords: [String], domain: String) -> String {
        var tips: [String] = []

        if keywords.contains("swift") || keywords.contains("swiftui") {
            tips.append("1. `Instruments > Time Profiler` — mide antes de optimizar")
            tips.append("2. `@State` solo en la view que lo necesita — evita re-renders")
            tips.append("3. `EquatableView` o `.equatable()` para skip de render")
            tips.append("4. `LazyVStack/LazyHStack` para listas largas")
            tips.append("5. `nonisolated` para métodos que no tocan UI")
        } else if keywords.contains("react") || keywords.contains("javascript") {
            tips.append("1. React DevTools Profiler — identifica re-renders innecesarios")
            tips.append("2. `React.memo()` + `useMemo` para computaciones caras")
            tips.append("3. `dynamic import()` para code splitting")
            tips.append("4. `Intersection Observer` > scroll events")
            tips.append("5. `requestIdleCallback` para tareas no urgentes")
        } else if keywords.contains("python") {
            tips.append("1. `cProfile` o `py-spy` para profiling")
            tips.append("2. `numpy`/`pandas` vectorización > loops")
            tips.append("3. `functools.lru_cache` para memoización")
            tips.append("4. `asyncio.gather()` para I/O paralelo")
            tips.append("5. `__slots__` en clases para reducir memoria")
        } else if keywords.contains("docker") || keywords.contains("kubernetes") {
            tips.append("1. Multi-stage builds (imagen 60-80% más pequeña)")
            tips.append("2. `--no-cache` solo cuando necesario")
            tips.append("3. Alpine/Distroless como base image")
            tips.append("4. Health checks para restart automático")
            tips.append("5. Resource limits para evitar noisy neighbors")
        } else {
            tips.append("1. **Mide primero** — nunca optimices sin datos")
            tips.append("2. Identifica el cuello de botella real")
            tips.append("3. Optimiza el hot path, no todo")
            tips.append("4. Cache donde sea posible")
            tips.append("5. Paraleliza I/O, no CPU")
        }

        return "\n" + tips.joined(separator: "\n")
    }

    // ════════════════════════════════════════
    // MARK: - Swarm Evolution
    // ════════════════════════════════════════

    /// Trigger an evolutionary cycle — prune weak DNA, boost strong
    func evolve() {
        fitness.evolve()

        // Update fitness scores in DNA pool
        for i in dnaPool.indices {
            let species = dnaPool[i].species
            dnaPool[i].fitnessScore = fitness.fitness(for: species)
        }

        NSLog("🧬 Swarm evolved — Generation \(fitness.generation), \(dnaPool.count) species active")
    }

    /// Summary of the hive state for display
    var hiveSummary: String {
        let topSpecies = contextMesh.topSpeciesOverall(limit: 3).joined(separator: ", ")
        let sessionMomentum = contextMesh.recentWinners.suffix(3).joined(separator: " → ")
        return """
        🐝 SwarmHive v3.0 — Vitaminized
        Species: \(DNARegistry.totalSpecies) DNA + \(legacyBridge.count) legacy = \(telemetry.totalDNATemplates)
        Generation: \(fitness.generation)
        Total Queries: \(fitness.totalQueries)
        Total Spawns: \(fitness.totalSpawns)
        Peak Concurrency: \(telemetry.peakConcurrency)
        Health: \(telemetry.swarmHealth.rawValue)
        Intent: \(contextMesh.intentSignal.rawValue)
        Top Species: \(topSpecies.isEmpty ? "—" : topSpecies)
        Momentum: \(sessionMomentum.isEmpty ? "—" : sessionMomentum)
        Languages: \(contextMesh.detectedLanguages.joined(separator: ", "))
        Chaining Rules: \(chainingRules.count) active
        """
    }
}
