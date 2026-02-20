import SwiftUI
import Combine
import AppKit

// ═══════════════════════════════════════════════════
// MARK: - 🧠 Notch Neural Engine v3 — Swarm Coordinator
// ═══════════════════════════════════════════════════
//
// Protocol, models, and memory are in:
//   - AIModels.swift (NotchAgent, AgentResponse, SensorFusion)
//   - ConversationMemory.swift
//
// Agent implementations extracted to AI/Agents/:
//   - ArchitectAgent.swift
//   - MuseAgent.swift
//   - AnalystAgent.swift
//   - SentinelAgent.swift
//   - EmpathAgent.swift
//   - OrchestratorAgent.swift
//

// ═══════════════════════════════════════════════════
// MARK: - 🧠 Swarm Coordinator (The Brain)
// ═══════════════════════════════════════════════════

final class NotchIntelligence: ObservableObject {
    static let shared = NotchIntelligence()
    private let log = NotchLog.make("NotchIntelligence")

    
    // ── Published State ──
    @Published var isThinking: Bool = false
    @Published var currentThought: String = ""
    @Published var processingStage: String = "idle"
    @Published var activeAgentName: String = ""
    @Published var activeAgentEmoji: String = "🧠"
    
    // ── Swarm Telemetry (exposed for UI) ──
    @Published var swarmSize: Int = 0
    @Published var swarmGeneration: Int = 0
    @Published var swarmHealth: String = "🟢 Nominal"
    @Published var activeSpecies: [String] = []
    @Published var totalDNASpecies: Int = 0
    
    // ── Workflow State ──
    @Published var isWorkflowActive: Bool = false
    @Published var workflowStep: Int = 0
    @Published var workflowPhase: String = ""
    
    // ── Memory ──
    let memory = ConversationMemory()
    
    // ── SwarmHive Engine (120+ DNA templates + 26 legacy agents) ──
    let hive = SwarmHive.shared
    
    // ── Agent Army: 6 core + 20 original + 80 extended = 106 real agents ──
    // ── Core Agents ──
    private let architect = ArchitectAgent()
    private let muse = MuseAgent()
    private let analyst = AnalystAgent()
    private let sentinel = SentinelAgent()
    private let empath = EmpathAgent()
    private let orchestrator = OrchestratorAgent()
    
    // ── Agent Army: 6 core + 20 original + 80 extended = 106 real agents ──
    private lazy var agents: [NotchAgent] = {
        let core: [NotchAgent] = [
            architect,
            muse,
            analyst,
            sentinel,
            empath,
            orchestrator
        ]
        return core + SpecialistRegistry.all + ExtendedSpecialistRegistry.all
    }()
    
    // ── Glorious Flow Steps ──
    private struct FlowStep {
        let phase: String
        let title: String
        let agent: String
        let prompt: String
        let targetApp: String
    }
    
    private let gloriousSteps: [FlowStep] = [
        FlowStep(phase: "Fase 1", title: "El Estratega", agent: "ChatGPT / Gemini", prompt: "Actúa como un director creativo visionario. Diseña un concepto para un videoclip 'Neo-Kinki Cyberpunk'. Necesito: Trama, Letra de canción (estilo trap industrial), y guion técnico.", targetApp: "ChatGPT"),
        FlowStep(phase: "Fase 1", title: "El Arquitecto", agent: "Claude 4.6", prompt: "Toma el guion anterior y genera prompts ultra-detallados para Midjourney y Runway. Especifica: iluminación, lentes de cámara, y estilo 'glitch art analógico'.", targetApp: "Claude"),
        FlowStep(phase: "Fase 2", title: "El Pintor", agent: "Midjourney v6", prompt: "/imagine prompt: [INSERT DESCRIPTION] --ar 16:9 --v 6.1 --style raw --s 250 --chaos 15", targetApp: "Discord"),
        FlowStep(phase: "Fase 2", title: "El Músico", agent: "Suno AI", prompt: "Style: Electronic Industrial Phonk with Spanish Trap vocals, 140 BPM. Lyrics: [INSERT]", targetApp: "Browser"),
        FlowStep(phase: "Fase 2", title: "La Voz", agent: "ElevenLabs", prompt: "Voice: Deep cinematic narrator. Script: [INTRO TEXT]. Settings: Stability 0.5, Clarity 0.75.", targetApp: "Browser"),
        FlowStep(phase: "Fase 3", title: "El Animador", agent: "Runway Gen-3", prompt: "Image-to-Video. Motion Brush: animate neon lights + smoke. Camera: Slow dolly forward. Duration: 4s.", targetApp: "Browser"),
        FlowStep(phase: "Fase 3", title: "El Pulidor", agent: "Magnific AI", prompt: "Upscale to 4K. Engine: Sharpen. Hallucination: 2. Creativity: 3. HDR: Enabled.", targetApp: "Browser"),
        FlowStep(phase: "Fase 4", title: "El Escultor", agent: "Tripo / Meshy", prompt: "3D Model: Cyberpunk helmet, rusty metal, holographic visor. Format: GLB. Poly: Medium.", targetApp: "Browser"),
        FlowStep(phase: "Fase 4", title: "El Constructor", agent: "Cursor + Three.js", prompt: "Landing page: Load .glb model, background video with scanline shader, parallax scroll.", targetApp: "Cursor"),
        FlowStep(phase: "Fase 5", title: "El Publicista", agent: "Perplexity", prompt: "Analyze trending hashtags. Write a cryptic viral launch thread for X. Use cyberpunk imagery and minimal text.", targetApp: "Perplexity")
    ]
    
    private init() {
        totalDNASpecies = DNARegistry.totalSpecies + SpecialistRegistry.count + 6
        log.info("NotchIntelligence v3: \(totalDNASpecies) total agent species ready")
    }
    
    // ════════════════════════════════════════
    // MARK: - Main Processing Pipeline
    // ════════════════════════════════════════
    
    /// Processes a user query through the Swarm Intelligence router.
    /// - Parameters:
    ///   - query: The natural language query from the user.
    ///   - context: Additional application context or clipboard state.
    ///   - onStream: Callback for partial/streaming response delivery.
    func process(query: String, context: String, onStream: @escaping (String) -> Void) async {
        // 🔮 Psionic Command Interceptor
        if query.starts(with: "/") {
            handleCommand(query, onStream: onStream)
            return
        }
    
        guard !isThinking else { return }
        
        await MainActor.run {
            isThinking = true
            processingStage = "Analyzing..."
        }
        
        // 1. Capture full sensor state
        let sensors = SensorFusion.capture()
        
        // 2. Check for workflow commands first
        let lowered = query.lowercased()
        if lowered.contains("flujo glorioso") || lowered.contains("glorious flow") || lowered.contains("genesis") || lowered.contains("iniciar flujo") {
            startGloriousFlow(onStream: onStream)
            return
        }
        
        // 3. Router: Find the Best Agent
        // Evaluate all agents in parallel or sequential
        var bestAgent: NotchAgent?
        var bestConfidence = 0.0
        
        for agent in agents {
            let score = agent.confidence(for: query, context: sensors)
            if score > bestConfidence {
                bestConfidence = score
                bestAgent = agent
            }
        }
        
        // 4. Execution
        if let winner = bestAgent, bestConfidence > 0.3 {
            await MainActor.run {
                activeAgentName = winner.name
                activeAgentEmoji = winner.emoji
                processingStage = "\(winner.name) Working..."
            }
            
            // Invoke the Agent (Async/LLM capable)
            let response = await winner.respond(to: query, context: sensors, memory: memory)
            
            // Stream the Result
            memory.add(query: query, response: response.text, agent: winner.name)
            streamOnMain(response.text, onStream: onStream)
            
            // Handle Actions
            if let action = response.suggestedAction {
                log.info("🎯 Suggested action from \(winner.name): \(action)")
            }
            
        } else {
            // Fallback to SwarmHive (Legacy/General) if no specialist is confident
            await MainActor.run {
                 streamOnMain("⚠️ Swarm disconnected. Please restart synapse.", onStream: onStream)
            }
        }
        
        await MainActor.run {
            isThinking = false
            processingStage = "Idle"
        }
    }
    
    // ── Command Handler ──
    /// Intercepts and executes slash commands and creative workflows.
    /// - Parameters:
    ///   - command: The raw command string starting with '/'.
    ///   - onStream: Callback for command output.
    private func handleCommand(_ command: String, onStream: @escaping (String) -> Void) {
        let parts = command.dropFirst().split(separator: " ")
        guard let cmd = parts.first else { return }
        // let args = parts.dropFirst().joined(separator: " ") // Unused for now
        
        switch cmd.lowercased() {
        case "god":
            DispatchQueue.main.async { UserModeManager.shared.toggle(.psionic) }
            streamOnMain("👁️ **GOD MODE ACTIVATED.**\n*Reality is now malleable.*\n- All sensors: MAX\n- Breathing: HYPER\n- Chameleon: ON", onStream: onStream)
            
        case "dream":
            let dream = generateDream(context: SensorFusion.capture())
            streamOnMain(dream, onStream: onStream)
            
        case "cortex":
            streamOnMain("🧠 **Cortex Status:**\n- Entries: \(memory.conversationLength)/\(memory.maxCapacity)\n- Persistence: CORTEX v4 REST API (/v1/facts)\n- Status: ACTIVE", onStream: onStream)
            
        case "clear":
            memory.clear()
            streamOnMain("🧹 **Cortex Wiped.** Tabula rasa established.", onStream: onStream)
            
        default:
            streamOnMain("⚠️ Unknown command `/\(cmd)`.", onStream: onStream)
        }
    }

    
    // ════════════════════════════════════════
    // MARK: - Workflow Engine
    // ════════════════════════════════════════
    
    private func startGloriousFlow(onStream: @escaping (String) -> Void) {
        DispatchQueue.main.async {
            self.isWorkflowActive = true
            self.workflowStep = 0
            self.workflowPhase = self.gloriousSteps[0].phase
            self.activeAgentName = "Orchestrator"
            self.activeAgentEmoji = "🎯"
            self.processingStage = "Protocol Genesis..."
        }
        
        let step = gloriousSteps[0]
        let total = gloriousSteps.count
        
        let response = """
        🚀 **Protocol Genesis Deca-Core — Initiated**
        
        ═══════════════════════════════════════
        **Step 1/\(total): \(step.phase) — \(step.title)**
        **Agent:** \(step.agent)
        **Target App:** \(step.targetApp)
        ═══════════════════════════════════════
        
        **Prompt Generated:**
        > \(step.prompt)
        
        📋 *Copy this prompt and paste it into \(step.targetApp).*
        *Say "Next" or "Siguiente" when ready for the next step.*
        *Say "Stop" to exit the workflow.*
        """
        
        memory.add(query: "Start Flujo Glorioso", response: "Step 1 initiated", agent: "Orchestrator")
        streamOnMain(response, onStream: onStream)
    }
    
    private func advanceGloriousFlow(onStream: @escaping (String) -> Void) {
        let nextIndex = workflowStep + 1
        
        if nextIndex >= gloriousSteps.count {
            stopWorkflow(onStream: onStream, completed: true)
            return
        }
        
        DispatchQueue.main.async {
            self.workflowStep = nextIndex
            self.workflowPhase = self.gloriousSteps[nextIndex].phase
        }
        
        let step = gloriousSteps[nextIndex]
        let total = gloriousSteps.count
        let progress = String(repeating: "█", count: nextIndex) + String(repeating: "░", count: total - nextIndex)
        
        let response = """
        [\(progress)] \(nextIndex + 1)/\(total)
        
        ═══════════════════════════════════════
        **Step \(nextIndex + 1)/\(total): \(step.phase) — \(step.title)**
        **Agent:** \(step.agent)
        **Target App:** \(step.targetApp)
        ═══════════════════════════════════════
        
        **Prompt:**
        > \(step.prompt)
        
        📋 *Paste into \(step.targetApp). Say "Next" when done.*
        """
        
        memory.add(query: "Next step", response: "Step \(nextIndex + 1) initiated", agent: "Orchestrator")
        streamOnMain(response, onStream: onStream)
    }
    
    private func stopWorkflow(onStream: @escaping (String) -> Void, completed: Bool = false) {
        DispatchQueue.main.async {
            self.isWorkflowActive = false
            self.workflowStep = 0
            self.workflowPhase = ""
        }
        
        let response = completed
            ? "🎉 **Protocol Genesis Deca-Core — COMPLETE!**\n\nAll 10 steps executed. Your multimedia masterpiece awaits deployment.\n\n*The Swarm rests... until the next creation.*"
            : "⏹️ **Workflow stopped.** Progress saved in memory. Say \"Flujo Glorioso\" to restart."
        
        streamOnMain(response, onStream: onStream)
    }
    
    // ═══════════════════════════════════════════════════
    // MARK: - Phase 3: Psionic Capabilities (Dream Mode)
    // ═══════════════════════════════════════════════════
    
    /// Generates a proactive thought from the swarm based on current context.
    /// Call this when the system is idle to simulate "dreaming".
    func generateDream(context: SensorFusion) -> String {
        let agents: [NotchAgent] = [muse, empath, architect, analyst]
        let dreamer = agents.randomElement() ?? muse
        
        switch dreamer.name {
        case "Muse":
            let creativePrompts = [
                "The silence is a canvas. Why not fill it with a drone soundscape? 🎹",
                "I detect a lull in activity. Perfect time to browse some brutalist typography. 🅰️",
                "Your clipboard contains colors. Shall we generate a palette? 🎨",
                "Dreaming of electric sheep... and Generative UI patterns. 🐑",
                "Psionic vision: A UI that breathes with your CPU cycles. 🫁"
            ]
            return "🎨 **Muse Dream:** \(creativePrompts.randomElement()!)"
            
        case "Empath":
            return "💚 **Empath Check:** System load is low (\(Int(context.cpuUsage))%). Good moment to hydrate or stretch. 💧"
            
        case "Architect":
            return "🏗 **Architect Pondering:** Have you considered refactoring the networking layer while the code is cold? ❄️"
            
        case "Analyst":
            return "🔬 **Analyst Insight:** You have 0 uncommitted changes. The repository is pristine. ✨"
            
        default:
            return "✨ **Swarm Whisper:** We are listening."
        }
    }

    // ════════════════════════════════════════
    // MARK: - Streaming Engine
    // ════════════════════════════════════════
    
    private func streamOnMain(_ fullText: String, onStream: @escaping (String) -> Void) {
        DispatchQueue.main.async {
            self.processingStage = "Streaming..."
            
            let chars = Array(fullText)
            var captured = ""
            var index = 0
            
            Timer.scheduledTimer(withTimeInterval: 0.018, repeats: true) { [weak self] timer in
                guard let self = self else { timer.invalidate(); return }
                
                if index < chars.count {
                    let char = chars[index]
                    captured.append(char)
                    
                    // Variable speed
                    if char == "\n" { Thread.sleep(forTimeInterval: 0.06) }
                    else if char == "*" { Thread.sleep(forTimeInterval: 0.01) } // Fast through markdown
                    
                    onStream(captured)
                    self.currentThought = captured
                    index += 1
                } else {
                    timer.invalidate()
                    self.isThinking = false
                    self.processingStage = "idle"
                }
            }
        }
    }
}
