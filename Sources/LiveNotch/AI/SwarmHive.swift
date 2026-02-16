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
// MARK: - Fitness Tracker (Evolutionary Learning)
// ═══════════════════════════════════════════════════════════════

/// Tracks agent performance over time and evolves the swarm.
/// Better-performing agent DNAs rise, poor ones are culled.
final class FitnessTracker: ObservableObject {
    static let shared = FitnessTracker()
    private let log = NotchLog.make("FitnessTracker")
    

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
        log.info("🧬 Swarm evolved to generation \(generation). Active species: \(dnaFitness.count)")
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
    private let log = NotchLog.make("SwarmTelemetry")
    

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
    private let log = NotchLog.make("SwarmHive")
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

        log.info("🐝 SwarmHive v3 initialized: \(DNARegistry.totalSpecies) DNA + \(legacyBridge.count) legacy = \(telemetry.totalDNATemplates) total species")
    }

    // ════════════════════════════════════════
    // MARK: - Swarm Spawn & Execute
    // ════════════════════════════════════════

    /// Spawn a swarm of micro-agents, evaluate, and reach consensus.
    /// This is the main entry point for query processing.
    /// Orchestrates the execution of multiple specialized agents to reach a consensus.
    /// - Parameters:
    ///   - query: The user's intent.
    ///   - sensors: Real-time environmental and clipboard data.
    ///   - memory: The current conversation state.
    /// - Returns: A consensus result containing the winning response and metadata.
    func swarmProcess(
        query: String,
        sensors: SensorFusion,
        memory: ConversationMemory
    ) async -> SwarmConsensusResult {

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
                let response = await legacyAgent.respond(to: query, context: sensors, memory: memory)
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
                agent.response = await generateResponse(for: agent, query: query, sensors: sensors, memory: memory)
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
        await MainActor.run { [swarm, result] in
            self.lastSwarmSize = swarm.count
            self.lastConsensus = result.protocol
            self.activeSpecies = result.breakdown.prefix(5).map { $0.species }
        }

        // Log swarm activity
        log.info("🐝 Swarm v3: \(swarm.count) spawned → \(respondedAgents.count) responded → \(result.protocol) in \(String(format: "%.1f", elapsed))ms | Intent: \(contextMesh.intentSignal.rawValue)")
        for vote in result.breakdown.prefix(5) {
            log.debug("   \(vote.emoji) \(vote.species): \(String(format: "%.2f", vote.confidence))")
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
    ) async -> String {
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
        let clipboardAnalysis = SwarmAnalysis.analyzeClipboard(sensors.clipboardContent, domain: domain, keywords: agent.dna.keywords)

        // 3. Real query intent classification
        let queryIntent = SwarmAnalysis.classifyQueryIntent(q)

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
            response += SwarmAnalysis.generateRealGuidance(for: matchedKeywords, domain: domain, species: species)

        case .debugging:
            response += "\n\n**🔧 Diagnóstico para \(topicSummary):**"
            response += SwarmAnalysis.generateDebuggingAdvice(for: matchedKeywords, domain: domain, clipboard: clipboardAnalysis)

        case .comparison:
            response += "\n\n**⚖️ Análisis comparativo:**"
            response += SwarmAnalysis.generateComparisonAdvice(for: matchedKeywords, domain: domain)

        case .optimization:
            response += "\n\n**⚡ Optimización de \(topicSummary):**"
            response += SwarmAnalysis.generateOptimizationAdvice(for: matchedKeywords, domain: domain)

        case .general:
            response += "\n\n**\(domain) — Análisis contextual:**"
            response += SwarmAnalysis.generateRealGuidance(for: matchedKeywords, domain: domain, species: species)
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

        log.info("🧬 Swarm evolved — Generation \(fitness.generation), \(dnaPool.count) species active")
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
