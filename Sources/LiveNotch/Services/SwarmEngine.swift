import SwiftUI
import Combine

// ═══════════════════════════════════════════════════
// MARK: - 🐝 SwarmEngine — The Hive Mind
// ═══════════════════════════════════════════════════
// Each "agent" is a lightweight async worker with:
//   - A visual identity (color, position, velocity)
//   - A lifecycle (health/tokens that deplete)
//   - Communication channels (can send results to others)
//
// The Engine manages spawning, killing, task dispatch,
// and provides observable state for the UI layer.

// ─── Agent Type ───
enum AgentRole: String, CaseIterable, Identifiable {
    case researcher   = "Researcher"
    case coder        = "Coder"
    case designer     = "Designer"
    case analyst      = "Analyst"
    case optimizer    = "Optimizer"
    case guardian     = "Guardian"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .researcher: return "magnifyingglass"
        case .coder:      return "chevron.left.forwardslash.chevron.right"
        case .designer:   return "paintbrush.pointed.fill"
        case .analyst:    return "chart.bar.xaxis"
        case .optimizer:  return "bolt.fill"
        case .guardian:   return "shield.checkered"
        }
    }
    
    var color: Color {
        switch self {
        case .researcher: return Color(hue: 0.52, saturation: 0.85, brightness: 0.95) // Cyan
        case .coder:      return Color(hue: 0.08, saturation: 0.90, brightness: 0.95) // Amber
        case .designer:   return Color(hue: 0.75, saturation: 0.70, brightness: 0.90) // Violet
        case .analyst:    return Color(hue: 0.35, saturation: 0.80, brightness: 0.85) // Green
        case .optimizer:  return Color(hue: 0.15, saturation: 0.85, brightness: 0.95) // Orange
        case .guardian:   return Color(hue: 0.60, saturation: 0.50, brightness: 0.90) // Steel
        }
    }
}

// ─── Agent Status ───
enum AgentStatus: Equatable {
    case idle
    case working(task: String)
    case transferring(to: UUID)   // Handing off data to another agent
    case dying                     // Health depleted, being absorbed
    case dead
}

// ─── The Agent ───
class SwarmAgent: Identifiable, ObservableObject {
    let id = UUID()
    let role: AgentRole
    let spawnTime = Date()
    
    @Published var status: AgentStatus = .idle
    @Published var health: Double = 1.0          // 0..1 — depletes with work
    @Published var currentTask: String = ""
    @Published var progress: Double = 0          // 0..1
    @Published var outputLog: [String] = []
    
    // ── Visual State (for particle rendering) ──
    @Published var position: CGPoint = .zero
    @Published var velocity: CGPoint = .zero
    @Published var targetPosition: CGPoint = .zero
    @Published var particleScale: CGFloat = 1.0
    @Published var glowIntensity: Double = 0.5
    
    // ── Connections ──
    @Published var collaborators: Set<UUID> = []
    
    init(role: AgentRole) {
        self.role = role
        // Random initial position within notch bounds
        self.position = CGPoint(
            x: CGFloat.random(in: 20...160),
            y: CGFloat.random(in: 8...26)
        )
        self.targetPosition = position
    }
    
    var isAlive: Bool {
        if case .dead = status { return false }
        return health > 0
    }
    
    var isWorking: Bool {
        if case .working = status { return true }
        return false
    }
    
    /// Simulate work — depletes health, advances progress
    func tick() {
        guard isAlive else { return }
        
        switch status {
        case .working:
            // Consume tokens
            health -= 0.002
            progress = min(progress + Double.random(in: 0.005...0.02), 1.0)
            glowIntensity = 0.6 + sin(Date().timeIntervalSince1970 * 3) * 0.3
            
            if progress >= 1.0 {
                outputLog.append("✅ Completed: \(currentTask)")
                status = .idle
                progress = 0
                glowIntensity = 0.3
            }
            
            if health <= 0 {
                status = .dying
                glowIntensity = 0.1
            }
            
        case .dying:
            health = max(health - 0.01, 0)
            particleScale *= 0.97
            if particleScale < 0.1 {
                status = .dead
            }
            
        case .idle:
            glowIntensity = 0.3 + sin(Date().timeIntervalSince1970 * 1.5) * 0.15
            // Drift slowly
            let drift = CGPoint(
                x: CGFloat.random(in: -0.3...0.3),
                y: CGFloat.random(in: -0.15...0.15)
            )
            targetPosition = CGPoint(
                x: max(10, min(170, targetPosition.x + drift.x)),
                y: max(5, min(30, targetPosition.y + drift.y))
            )
            
        default: break
        }
        
        // Smooth position interpolation — lerp 0.22 compensates for 10fps (was 0.08 at 30fps)
        let lerp: CGFloat = 0.22
        position = CGPoint(
            x: position.x + (targetPosition.x - position.x) * lerp,
            y: position.y + (targetPosition.y - position.y) * lerp
        )
    }
    
    func assignTask(_ task: String) {
        currentTask = task
        status = .working(task: task)
        progress = 0
        glowIntensity = 0.8
    }
    
    func connectTo(_ other: SwarmAgent) {
        collaborators.insert(other.id)
        other.collaborators.insert(self.id)
    }
}

// ═══════════════════════════════════════════════════
// MARK: - 🏗️ SwarmEngine — Orchestrator
// ═══════════════════════════════════════════════════

@MainActor
class SwarmEngine: ObservableObject {
    
    @Published var agents: [SwarmAgent] = []
    @Published var isActive = false
    @Published var totalTasksCompleted: Int = 0
    @Published var swarmLog: [SwarmLogEntry] = []
    
    private var tickTimer: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    
    struct SwarmLogEntry: Identifiable {
        let id = UUID()
        let timestamp = Date()
        let agentRole: AgentRole
        let message: String
    }
    
    var livingAgents: [SwarmAgent] {
        agents.filter { $0.isAlive }
    }
    
    var activeAgents: [SwarmAgent] {
        agents.filter { $0.isWorking }
    }
    
    /// All connections between living agents (for drawing lines)
    var connections: [(SwarmAgent, SwarmAgent)] {
        var result: [(SwarmAgent, SwarmAgent)] = []
        var seen = Set<String>()
        
        for agent in livingAgents {
            for collabID in agent.collaborators {
                let key = [agent.id.uuidString, collabID.uuidString].sorted().joined()
                if !seen.contains(key), let other = livingAgents.first(where: { $0.id == collabID }) {
                    result.append((agent, other))
                    seen.insert(key)
                }
            }
        }
        return result
    }
    
    // ═══════════════════════════════════════
    // MARK: - Lifecycle
    // ═══════════════════════════════════════
    
    func activate() {
        guard !isActive else { return }
        isActive = true
        
        // PERF: 10fps is sufficient for agent positions — lerp compensates (was 30fps)
        tickTimer = Timer.publish(every: 1.0 / 10.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
        
        log(.researcher, "Swarm activated")
    }
    
    func deactivate() {
        isActive = false
        tickTimer?.cancel()
        tickTimer = nil
    }

    // deinit removed - AnyCancellable handles cleanup automatically

    
    func tick() {
        for agent in livingAgents {
            agent.tick()
        }
        
        // Absorb dead agents' memory into nearest living agent
        for agent in agents where agent.status == .dead {
            absorbDeadAgent(agent)
        }
        
        // Clean up fully dead agents
        agents.removeAll { $0.status == .dead && $0.particleScale < 0.05 }
        
        // PERF: Auto-deactivate when no agents remain
        if livingAgents.isEmpty && isActive {
            deactivate()
        }
        
        objectWillChange.send()
    }
    
    // ═══════════════════════════════════════
    // MARK: - Agent Management
    // ═══════════════════════════════════════
    
    @discardableResult
    func spawn(_ role: AgentRole) -> SwarmAgent {
        let agent = SwarmAgent(role: role)
        agents.append(agent)
        log(role, "Agent spawned: \(role.rawValue)")
        
        if !isActive { activate() }
        
        return agent
    }
    
    func kill(_ agent: SwarmAgent) {
        agent.status = .dying
        log(agent.role, "Agent terminated: \(agent.role.rawValue)")
    }
    
    private func absorbDeadAgent(_ dead: SwarmAgent) {
        // Find nearest living agent
        guard let nearest = livingAgents
            .filter({ $0.id != dead.id })
            .min(by: { distance($0.position, dead.position) < distance($1.position, dead.position) })
        else { return }
        
        // Transfer health bonus
        nearest.health = min(nearest.health + 0.15, 1.0)
        
        // Inherit memory
        nearest.outputLog.append(contentsOf: dead.outputLog.suffix(3))
        nearest.collaborators.formUnion(dead.collaborators)
        nearest.collaborators.remove(dead.id)
        
        log(nearest.role, "\(nearest.role.rawValue) absorbed memory from \(dead.role.rawValue)")
    }
    
    // ═══════════════════════════════════════
    // MARK: - File Drop → Swarm Dispatch
    // ═══════════════════════════════════════
    
    /// Auto-organize agents to process a dropped file
    func dispatchFile(_ url: URL) {
        let ext = url.pathExtension.lowercased()
        let name = url.lastPathComponent
        
        log(.analyst, "File received: \(name)")
        
        // 1. Spawn detector agent
        let detector = spawn(.analyst)
        detector.assignTask("Analyzing \(name)")
        
        // 2. Spawn specialist based on file type
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self = self else { return }
            
            let specialist: SwarmAgent
            switch ext {
            case "py", "js", "ts", "swift", "rs", "go":
                specialist = self.spawn(.coder)
                specialist.assignTask("Parsing code: \(name)")
            case "png", "jpg", "jpeg", "webp", "svg", "figma":
                specialist = self.spawn(.designer)
                specialist.assignTask("Processing image: \(name)")
            case "csv", "json", "xml", "plist":
                specialist = self.spawn(.analyst)
                specialist.assignTask("Parsing data: \(name)")
            case "pdf", "md", "txt", "doc":
                specialist = self.spawn(.researcher)
                specialist.assignTask("Reading document: \(name)")
            default:
                specialist = self.spawn(.optimizer)
                specialist.assignTask("Processing: \(name)")
            }
            
            // Connect detector → specialist
            detector.connectTo(specialist)
        }
        
        // 3. Spawn optimizer after initial analysis
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            
            let optimizer = self.spawn(.optimizer)
            optimizer.assignTask("Optimizing output for \(name)")
            
            // Connect to all existing agents
            for agent in self.livingAgents where agent.id != optimizer.id {
                optimizer.connectTo(agent)
            }
        }
    }
    
    // ═══════════════════════════════════════
    // MARK: - Demo / Quick Spawn
    // ═══════════════════════════════════════
    
    /// Spawn a demo swarm with diverse agents
    func spawnDemoSwarm() {
        let roles: [AgentRole] = [.researcher, .coder, .designer, .analyst]
        let tasks = [
            "Scanning codebase for patterns",
            "Refactoring authentication module",
            "Generating UI component variants",
            "Analyzing performance metrics"
        ]
        
        for (i, role) in roles.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.3) { [weak self] in
                let agent = self?.spawn(role)
                agent?.assignTask(tasks[i])
                
                // Connect sequential agents
                if i > 0, let prev = self?.agents[safe: i - 1] {
                    agent?.connectTo(prev)
                }
            }
        }
    }
    
    // ═══════════════════════════════════════
    // MARK: - Helpers
    // ═══════════════════════════════════════
    
    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2))
    }
    
    private func log(_ role: AgentRole, _ message: String) {
        let entry = SwarmLogEntry(agentRole: role, message: message)
        swarmLog.append(entry)
        // Cap log at 50 entries
        if swarmLog.count > 50 {
            swarmLog.removeFirst(swarmLog.count - 50)
        }
    }
}

// ── Array Safe Subscript ──
extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
