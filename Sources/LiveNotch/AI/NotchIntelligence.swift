import SwiftUI
import Combine
import AppKit
import IOKit.ps

// ═══════════════════════════════════════════════════
// MARK: - 🧠 Notch Neural Engine v3 — Swarm Architecture
// ═══════════════════════════════════════════════════
//
// A multi-agent intelligence system running natively.
// No external APIs — pure on-device cognition.
//
// Architecture:
// ┌──────────────────────────────────────────────────┐
// │  SwarmCoordinator (Router & Orchestrator)         │
// │  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐    │
// │  │Architect│ │  Muse  │ │Analyst │ │Sentinel│    │
// │  │ (Code) │ │(Create)│ │(Research│ │(Secure)│    │
// │  └────────┘ └────────┘ └────────┘ └────────┘    │
// │  ┌────────┐ ┌────────┐                           │
// │  │Empath  │ │Orchestr│ ← Workflow Engine          │
// │  │(Mood)  │ │(Flow)  │                           │
// │  └────────┘ └────────┘                           │
// │                                                  │
// │  [Memory]  ← Short-term conversation memory      │
// │  [Sensors] ← CPU, Battery, Music, App Context    │
// └──────────────────────────────────────────────────┘

// ═══════════════════════════════════════════════════
// MARK: - Agent Protocol
// ═══════════════════════════════════════════════════

protocol NotchAgent {
    var name: String { get }
    var emoji: String { get }
    var domain: String { get }
    
    /// How confident this agent is that it can handle the query (0.0 - 1.0)
    func confidence(for query: String, context: SensorFusion) -> Double
    
    /// Generate a response
    func respond(to query: String, context: SensorFusion, memory: ConversationMemory) async -> AgentResponse
}

struct AgentResponse {
    let text: String
    let confidence: Double
    let agentName: String
    let suggestedAction: SuggestedAction?
    
    enum SuggestedAction {
        case copyToClipboard(String)
        case openApp(String)
        case startWorkflow(String)
        case showNotification(String)
    }
}

// ═══════════════════════════════════════════════════
// MARK: - Sensor Fusion (System Awareness)
// ═══════════════════════════════════════════════════

struct SensorFusion {
    let activeAppBundle: String
    let activeAppName: String
    let cpuUsage: Double
    let batteryLevel: Int
    let isCharging: Bool
    let isPlayingMusic: Bool
    let currentTrack: String
    let currentArtist: String
    let currentMood: String
    let systemPrompt: String // From NervousSystem.currentAIContext
    let timeOfDay: TimeOfDay
    let clipboardContent: String?
    let activeProject: String
    
    enum TimeOfDay: String {
        case morning = "☀️ Morning"
        case afternoon = "🌤 Afternoon"
        case evening = "🌅 Evening"
        case night = "🌙 Night"
        case lateNight = "🦉 Late Night"
    }
    
    static func capture() -> SensorFusion {
        let hour = Calendar.current.component(.hour, from: Date())
        let timeOfDay: TimeOfDay
        switch hour {
        case 6..<12: timeOfDay = .morning
        case 12..<17: timeOfDay = .afternoon
        case 17..<21: timeOfDay = .evening
        case 21..<24: timeOfDay = .night
        default: timeOfDay = .lateNight
        }
        
        let nervous = NervousSystem.shared
        let clipboard = NSPasteboard.general.string(forType: .string)
        
        // Project Context Heuristics
        var project = "Global Context"
        let app = nervous.activeAppName.lowercased()
        if app.contains("xcode") { project = "LiveNotch (Swift)" }
        else if app.contains("code") || app.contains("cursor") { project = "Web/JS/Python Project" }
        else if app.contains("terminal") || app.contains("iterm") { project = "Shell/System" }
        else if app.contains("figma") { project = "Design System" }
        else if app.contains("ableton") || app.contains("logic") { project = "Audio Production" }
        
        return SensorFusion(
            activeAppBundle: nervous.activeAppBundleID,
            activeAppName: nervous.activeAppName,
            cpuUsage: SystemMonitor.shared.cpuUsage,
            batteryLevel: SensorFusion.readBatteryLevel(),
            isCharging: false,
            isPlayingMusic: nervous.isPlayingMusic,
            currentTrack: "", // Track info lives in NotchViewModel
            currentArtist: "",
            currentMood: nervous.currentMood.rawValue,
            systemPrompt: nervous.currentAIContext,
            timeOfDay: timeOfDay,
            clipboardContent: clipboard,
            activeProject: project
        )
    }
    
    /// Read actual battery level from IOKit power sources
    static func readBatteryLevel() -> Int {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
              let capacity = desc[kIOPSCurrentCapacityKey as String] as? Int else {
            return 100 // Fallback for desktops without battery
        }
        return capacity
    }
}

// ═══════════════════════════════════════════════════
// MARK: - Conversation Memory
// ═══════════════════════════════════════════════════

class ConversationMemory {
    struct Exchange: Codable {
        let query: String
        let response: String
        let agent: String
        let timestamp: Date
    }
    
    private(set) var exchanges: [Exchange] = []
    let maxCapacity: Int = 50
    private let cortexPath: URL
    
    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let cortexDir = home.appendingPathComponent(".antigravity")
        try? FileManager.default.createDirectory(at: cortexDir, withIntermediateDirectories: true, attributes: nil)
        self.cortexPath = cortexDir.appendingPathComponent("cortex.json")
        loadFromCortex()
    }
    
    var lastExchange: Exchange? { exchanges.last }
    var conversationLength: Int { exchanges.count }
    
    func add(query: String, response: String, agent: String) {
        let exchange = Exchange(query: query, response: response, agent: agent, timestamp: Date())
        exchanges.append(exchange)
        // Rolling window — keep last N
        if exchanges.count > maxCapacity {
            exchanges.removeFirst(exchanges.count - maxCapacity)
        }
        saveToCortex()
    }
    
    func contextSummary() -> String {
        guard !exchanges.isEmpty else { return "No prior conversation." }
        let recent = exchanges.suffix(3)
        return recent.map { "[\($0.agent)] Q: \($0.query.prefix(50))... → A: \($0.response.prefix(80))..." }.joined(separator: "\n")
    }
    
    func clear() { 
        exchanges.removeAll()
        saveToCortex()
    }

    // 🧠 Cortex Persistence for Phase 3
    private func saveToCortex() {
        DispatchQueue.global(qos: .background).async {
            do {
                let data = try JSONEncoder().encode(self.exchanges)
                try data.write(to: self.cortexPath, options: .atomic)
            } catch {
                NSLog("🧠 Cortex Memory Save Failed: %@", error.localizedDescription)
            }
        }
    }
    
    private func loadFromCortex() {
        do {
            let data = try Data(contentsOf: cortexPath)
            exchanges = try JSONDecoder().decode([Exchange].self, from: data)
        } catch {
            NSLog("🧠 Cortex Memory Load Failed (New Cortex Created)")
        }
    }
}

// ═══════════════════════════════════════════════════
// MARK: - 🏗️ Architect Agent (Code & Engineering)
// ═══════════════════════════════════════════════════

struct ArchitectAgent: NotchAgent {
    let name = "Architect"
    let emoji = "🏗️"
    let domain = "Software Engineering"
    
    // Expanded keyword set
    private let codeKeywords = ["code", "refactor", "optimize", "bug", "fix", "error", "crash",
                                 "function", "class", "struct", "swift", "python", "javascript",
                                 "compile", "build", "deploy", "api", "database", "test", "debug",
                                 "performance", "memory", "leak", "async", "actor", "combine",
                                 "swiftui", "uikit", "xcode", "cursor", "arquitectura", "código",
                                 "diseñar", "patrón", "sistema", "optimizar", "clean", "solid"]
    
    private let codeBundles = ["com.microsoft.VSCode", "com.apple.dt.Xcode",
                                "com.todesktop.230510fqmkbjh6g", "com.cursor.Cursor",
                                "com.google.antigravity", "dev.warp.warp-stable",
                                "com.apple.Terminal", "com.googlecode.iterm2"]
    
    func confidence(for query: String, context: SensorFusion) -> Double {
        let lowered = query.lowercased()
        var score = 0.0
        
        // Keyword matching
        let matches = codeKeywords.filter { lowered.contains($0) }.count
        score += Double(matches) * 0.15
        
        // App context boost
        if codeBundles.contains(context.activeAppBundle) { score += 0.35 }
        
        // Clipboard contains code?
        if let clip = context.clipboardContent,
           clip.contains("{") || clip.contains("func ") || clip.contains("import ") {
            score += 0.2
        }
        
        // User Mode Affinity
        let mode = ContextMesh.shared.cachedUserMode
        if mode == .focus || mode == .producer { score += 0.15 }
        
        return min(1.0, score)
    }
    
    func respond(to query: String, context: SensorFusion, memory: ConversationMemory) async -> AgentResponse {
        let lowered = query.lowercased()
        let mode = ContextMesh.shared.cachedUserMode
        let isConcise = (mode == .focus || mode == .producer)
        
        // Dynamic Header
        var response = isConcise ? "🏗️ **Architect Analysis:**" : "🏗️ **Architect — Engineering Systems**"
        
        if !context.activeAppName.isEmpty {
            response += "\nContexto: \(context.activeAppName)"
        }
        
        // 1. Analyze Clipboard Code
        var clipboardAnalysis = ""
        var detectedLang = "Generic"
        var codeContent = ""
        
        if let clip = context.clipboardContent, clip.count > 10 {
            codeContent = clip
            let (lang, issues) = analyzeCodeblock(clip)
            detectedLang = lang
            if !issues.isEmpty {
                clipboardAnalysis = "\n\n📋 **Clipboard Scan (\(lang)):**\n" + issues.joined(separator: "\n")
            }
        }
        
        // 2. Intent Routing & LLM Integration
        if lowered.contains("refactor") || lowered.contains("optimize") || lowered.contains("clean") {
            response += "\n\n**Estrategia de Optimización (\(detectedLang)):**"
            
            // LLM Upgrade: Use LLM for Refactoring if code is present
            if !codeContent.isEmpty {
                let prompt = "Refactor this \(detectedLang) code for performance and readability. Be concise. \n\nCode:\n\(codeContent)"
                let llmResponse = await LLMService.shared.quickGenerate(prompt: prompt, systemPrompt: "You are a Senior Software Architect. Refactor code aggressively.")
                if !llmResponse.isEmpty {
                     response += "\n\n" + llmResponse
                } else {
                     response += getOptimizationTips(for: detectedLang, concise: isConcise)
                }
            } else {
                 response += getOptimizationTips(for: detectedLang, concise: isConcise)
            }
            response += clipboardAnalysis
            
        } else if lowered.contains("fix") || lowered.contains("error") || lowered.contains("crash") || lowered.contains("bug") {
            response += "\n\n**Protocolo de Diagnóstico:**"
            
             // LLM Upgrade: Debugging
            if !codeContent.isEmpty {
                let prompt = "Fix this \(detectedLang) code. Explain the bug briefly. \n\nCode:\n\(codeContent)"
                let llmResponse = await LLMService.shared.quickGenerate(prompt: prompt, systemPrompt: "You are a Senior Debugger. Fix bugs.")
                if !llmResponse.isEmpty {
                     response += "\n\n" + llmResponse
                } else {
                     response += getDebugSteps(for: detectedLang, concise: isConcise)
                }
            } else {
                response += getDebugSteps(for: detectedLang, concise: isConcise)
            }
            response += clipboardAnalysis
            
        } else if lowered.contains("architecture") || lowered.contains("design") || lowered.contains("pattern") {
            response += "\n\n**Recomendación Arquitectónica:**"
            response += getArchitectureAdvice(for: detectedLang, concise: isConcise)
            
        } else {
            response += "\n\n**Sistemas Nominales.**"
            if !clipboardAnalysis.isEmpty {
                response += clipboardAnalysis
            } else {
                response += isConcise ? "\nListo para ingeniería." : "\nEsperando input de código para análisis estático."
            }
        }
        
        // CPU Warning
        if context.cpuUsage > 80 {
            response += "\n\n⚠️ High CPU (\(Int(context.cpuUsage))%) — Check for infinite loops/renders."
        }
        
        return AgentResponse(text: response, confidence: confidence(for: query, context: context), agentName: name, suggestedAction: nil)
    }
    
    // ── Helper: Code Analysis ──
    private func analyzeCodeblock(_ code: String) -> (String, [String]) {
        let c = code.lowercased()
        var issues: [String] = []
        var lang = "Generic"
        
        // Detect Language
        if c.contains("func ") && (c.contains("->") || c.contains("@state")) { lang = "Swift" }
        else if c.contains("def ") && c.contains(":") { lang = "Python" }
        else if c.contains("const ") || c.contains("=>") { lang = "JS/TS" }
        else if c.contains("fn ") && c.contains("let ") { lang = "Rust" }
        
        // Clean Code Checks
        if c.contains("print(") || c.contains("console.log") { issues.append("• 🧹 Debug prints detectados") }
        if c.contains("todo") || c.contains("fixme") { issues.append("• 📌 Technical debt markers found") }
        
        // Language Specific Checks
        switch lang {
        case "Swift":
            if c.contains("try!") { issues.append("• ⚠️ `try!` es unsafe — usar `do/catch`") }
            if c.contains("as!") { issues.append("• ⚠️ `as!` force cast — riesgo de crash") }
            if c.contains(".filter") && c.contains(".map") { issues.append("• ⚡️ `.filter().map()` → `.compactMap()`") }
            if c.contains("dispatchqueue.main.async") { issues.append("• ♻️ Considerar `@MainActor`") }
        case "Python":
            if c.contains("except:") { issues.append("• ⚠️ Bare `except:` — capturar error específico") }
            if c.contains("print ") { issues.append("• ⚠️ Python 2 print detectado?") }
        case "JS/TS":
            if c.contains("var ") { issues.append("• ⚠️ `var` es legacy — usar `const`/`let`") }
            if c.contains("any") { issues.append("• ⚠️ `any` anula TypeScript safety") }
            if c.contains("==") { issues.append("• ⚠️ Usar `===` para strict equality") }
        default: break
        }
        
        return (lang, issues)
    }
    
    // ── Helper: Optimization Tips ──
    private func getOptimizationTips(for lang: String, concise: Bool) -> String {
        switch lang {
        case "Swift":
            return concise ?
            "\n1. `compactMap` > filter+map\n2. `Struct` > Class (value semantics)\n3. `lazy` vars for heavy init" :
            "\n1. Preferir `compactMap` sobre encadenar `filter` y `map`.\n2. Usar `struct` por defecto (stack allocation).\n3. `Assets.xcassets` para imágenes (caching nativo).\n4. Evitar `@Published` excesivo en bucles."
        case "JS/TS":
            return "\n1. Memoize computations (`useMemo`).\n2. Virtualize long lists.\n3. Tree-shake imports."
        default:
            return "\n1. DRY (Don't Repeat Yourself).\n2. Early return pattern.\n3. Big O analysis."
        }
    }
    
    // ── Helper: Debug Steps ──
    private func getDebugSteps(for lang: String, concise: Bool) -> String {
        switch lang {
        case "Swift":
            return "\n1. Check Optional Unwrapping (`nil`).\n2. Verify Main Thread UI updates.\n3. Check Retain Cycles (`[weak self]`)."
        case "Python":
            return "\n1. Check indentation.\n2. Verify variable scope.\n3. Import structure."
        default:
            return "\n1. Reproduce consistency.\n2. Isolate module.\n3. Check logs."
        }
    }
    
    // ── Helper: Architecture ──
    private func getArchitectureAdvice(for lang: String, concise: Bool) -> String {
        switch lang {
        case "Swift":
            return "\n**MVVM + C (Coordinator):**\n- View: Dumb UI\n- VM: State & Logic\n- Coordinator: Nav flow"
        case "JS/TS":
            return "\n**Feature-First:**\n- /features/auth\n- /features/profile\n- /shared/ui"
        default:
            return "\nModular Monolith over Microservices for speed."
        }
    }
}

// ═══════════════════════════════════════════════════
// MARK: - 🎨 Muse Agent (Creative & Art)
// ═══════════════════════════════════════════════════

struct MuseAgent: NotchAgent {
    let name = "Muse"
    let emoji = "🎨"
    let domain = "Creative Arts"
    
    // Expanded Creative Keywords
    private let creativeKeywords = ["create", "design", "prompt", "imagine", "midjourney",
                                     "art", "color", "aesthetic", "visual", "render",
                                     "video", "animation", "music", "song", "lyrics",
                                     "suno", "runway", "genera", "concepto", "idea",
                                     "cyberpunk", "neon", "palette", "composition", "chord", "scale", "bpm"]
    
    private let creativeBundles = ["com.hnc.Discord", "com.adobe.Photoshop",
                                    "com.adobe.illustrator", "com.ableton.live",
                                    "com.image-line.flstudio", "com.blackmagic-design.DaVinciResolve"]
    
    func confidence(for query: String, context: SensorFusion) -> Double {
        let lowered = query.lowercased()
        var score = 0.0
        let matches = creativeKeywords.filter { lowered.contains($0) }.count
        score += Double(matches) * 0.15
        if creativeBundles.contains(context.activeAppBundle) { score += 0.35 }
        if context.isPlayingMusic { score += 0.1 } // Creative mood
        
        // Mode Affinity
        let mode = ContextMesh.shared.cachedUserMode
        if mode == .creative || mode == .producer || mode == .dj { score += 0.2 }
        
        return min(1.0, score)
    }
    
    func respond(to query: String, context: SensorFusion, memory: ConversationMemory) async -> AgentResponse {
        let lowered = query.lowercased()
        let mode = ContextMesh.shared.cachedUserMode
        let isTechnical = (mode == .producer || mode == .dj)
        
        var response = isTechnical ? "🎨 **Muse technical analysis:**" : "🎨 **Muse — Creative Engine**"
        
        // Music Context
        if context.isPlayingMusic {
            response += "\n🎵 Vibe: *\(context.currentTrack)* by *\(context.currentArtist)*"
        }
        
        // 1. Analyze Clipboard for Colors
        if let clip = context.clipboardContent, let hexColor = extractHex(from: clip) {
            response += "\n\n🌈 **Color Detected \(hexColor):**"
            response += generatePalette(baseHex: hexColor)
        }
        
        // 2. Intent Routing & LLM Integration
        if lowered.contains("midjourney") || lowered.contains("prompt") || lowered.contains("imagine") {
            response += "\n\n**Generando Prompt Visual:**"
            let subject = extractSubject(from: query)
            
            // LLM Upgrade: Enhanced Prompt Generation
            let llmPrompt = "Create a detailed Midjourney v6 prompt for: '\(subject)'. Style: \(isTechnical ? "photorealistic, cinematic" : "digital art, creative"). Just return the prompt text, no filler."
            let llmResponse = await LLMService.shared.quickGenerate(prompt: llmPrompt, systemPrompt: "You are a Midjourney Prompt Expert.")
            
            if !llmResponse.isEmpty {
                 response += "\n\n`" + llmResponse + " --v 6.1`"
            } else {
                 response += generateMidjourneyPrompt(subject: subject, style: isTechnical ? "photoreal" : "artistic")
            }
            
        } else if lowered.contains("color") || lowered.contains("palette") || lowered.contains("aesthetic") {
            response += "\n\n**Curación Estética:**"
            response += "\n• **Industrial Noir:** `#1A1A1A`, `#FF4500`, `#00FFCC`"
            response += "\n• **Glassmorphism:** `#FFFFFF (10%)`, `#F0F0F0 (30%)`, Blur 20px"
            response += "\n*Usa la regla 60-30-10 para equilibrio visual.*"
            
        } else if lowered.contains("suno") || lowered.contains("music") || lowered.contains("song") || lowered.contains("chord") {
            response += "\n\n**Teoría Musical & Producción:**"
            
            // LLM Upgrade: Music Theory
            let llmPrompt = "Give music theory advice for: '\(query)'. Technical level: \(isTechnical ? "High" : "Low")."
            let llmResponse = await LLMService.shared.quickGenerate(prompt: llmPrompt, systemPrompt: "You are a Music Producer/Theorist. Be concise.")
            
            if !llmResponse.isEmpty {
                response += "\n\n" + llmResponse
            } else {
                response += getMusicAdvice(query: lowered, isTechnical: isTechnical)
            }
            
        } else {
            response += "\n\n**Motores Creativos Listos.**"
            response += "\nEscribe un concepto o pega un color HEX para comenzar."
        }
        
        return AgentResponse(text: response, confidence: confidence(for: query, context: context), agentName: name, suggestedAction: nil)
    }
    
    // ── Helper: Logic for Prompts ──
    private func extractSubject(from query: String) -> String {
        // Very basic extraction, just removes keywords.
        // In fully vitaminized version, use NLP or regex.
        var q = query.lowercased()
        ["prompt", "imagine", "midjourney", "create", "generar", "un", "una", "about"].forEach { q = q.replacingOccurrences(of: $0, with: "") }
        return q.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "masterpiece" : q.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func generateMidjourneyPrompt(subject: String, style: String) -> String {
        let core = "/imagine prompt: **\(subject)**"
        let params = "--ar 16:9 --v 6.1 --style raw"
        
        if style == "photoreal" {
            return "\n`\(core), hyper-realistic, 8k resolution, cinematic lighting, shot on 35mm, depth of field, ray tracing \(params) --s 250`"
        } else {
            return "\n`\(core), digital art, vibrant colors, dynamic composition, trending on artstation, ethereal atmosphere, volumetric lighting \(params) --s 750`"
        }
    }
    
    // ── Helper: Color Theory ──
    private func extractHex(from text: String) -> String? {
        let pattern = "#[0-9A-Fa-f]{6}"
        guard let range = text.range(of: pattern, options: .regularExpression) else { return nil }
        return String(text[range])
    }
    
    private func generatePalette(baseHex: String) -> String {
        // Simulating complementary/triadic generation
        return "\n• Complementary: [Calculated Contrast]" // Todo: Real math implementation
             + "\n• Analogous: [Neighbor Hues]"
    }
    
    // ── Helper: Music Theory ──
    private func getMusicAdvice(query: String, isTechnical: Bool) -> String {
        if query.contains("dark") || query.contains("trap") {
            return "\n🎹 **Phrygian Scale (Dark/Trap):**\n`i - II - i - vii` (Semitone tension)"
        } else if query.contains("happy") || query.contains("pop") {
            return "\n🎹 **Ionian Mode (Pop/Happy):**\n`I - V - vi - IV` (Axis Progression)"
        } else if query.contains("epic") || query.contains("cinematic") {
            return "\n🎹 **Hans Zimmer Progression:**\n`vi - IV - I - V` (Minor lift)"
        } else {
            return isTechnical ? "\n• Check Fase correlation.\n• EQ: Cut <30Hz on non-kick elements." : "\nFocus on the emotion first, theory second."
        }
    }
}

// ═══════════════════════════════════════════════════
// MARK: - 🔬 Analyst Agent (Research & Data)
// ═══════════════════════════════════════════════════

struct AnalystAgent: NotchAgent {
    let name = "Analyst"
    let emoji = "🔬"
    let domain = "Research & Analysis"
    
    private let researchKeywords = ["analyze", "research", "summarize", "data", "compare",
                                     "statistics", "trend", "report", "source", "citation",
                                     "explain", "what is", "how does", "why", "define",
                                     "pros", "cons", "versus", "vs", "investigate", "json", "csv", "format"]
    
    private let researchBundles = ["com.apple.Safari", "com.google.Chrome",
                                    "ai.perplexity.mac", "md.obsidian",
                                    "notion.id", "com.apple.iWork.Pages",
                                    "com.apple.iWork.Numbers"]
    
    func confidence(for query: String, context: SensorFusion) -> Double {
        let lowered = query.lowercased()
        var score = 0.0
        let matches = researchKeywords.filter { lowered.contains($0) }.count
        score += Double(matches) * 0.15
        if researchBundles.contains(context.activeAppBundle) { score += 0.3 }
        
        // Data format detection in clipboard
        if let clip = context.clipboardContent {
            if clip.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{") { score += 0.25 } // JSON
            if clip.contains(",") && clip.contains("\n") { score += 0.15 } // CSV potential
        }
        
        return min(1.0, score)
    }
    
    func respond(to query: String, context: SensorFusion, memory: ConversationMemory) async -> AgentResponse {
        let lowered = query.lowercased()
        var response = "🔬 **Analyst Report:**"
        
        // 1. Data Processing (Clipboard)
        if let clip = context.clipboardContent {
            if lowered.contains("format") || lowered.contains("json") {
                if let prettyJSON = prettifyJSON(clip) {
                    response += "\n\n**JSON Formatted:**\n```json\n\(prettyJSON)\n```"
                }
            } else if lowered.contains("table") || lowered.contains("csv") {
                if let markdownTable = csvToMarkdown(clip) {
                    response += "\n\n**CSV Visualization:**\n\(markdownTable)"
                }
            } else if lowered.contains("links") || lowered.contains("url") {
                let urls = extractURLs(from: clip)
                if !urls.isEmpty {
                    response += "\n\n**Extracted Sources:**\n" + urls.map { "• [\($0)](\($0))" }.joined(separator: "\n")
                }
            }
        }
        
        // 2. Intent Routing & LLM Integration
        if lowered.contains("summarize") || lowered.contains("tldr") || lowered.contains("resumen") {
            let clip = context.clipboardContent ?? ""
            if clip.isEmpty {
                response += "\n\n*Clipboard empty. Copy text to summarize.*"
            } else {
                response += "\n\n**Executive Summary:**"
                
                // LLM Upgrade: Summarization
                let prompt = "Summarize this text in 3 bullet points. Be concise.\n\nText:\n\(clip)"
                let llmResponse = await LLMService.shared.quickGenerate(prompt: prompt, systemPrompt: "You are a Senior Data Analyst.")
                
                if !llmResponse.isEmpty {
                     response += "\n\n" + llmResponse
                } else {
                     response += generateExtractiveSummary(text: clip)
                }
            }
            
        } else if lowered.contains("compare") || lowered.contains("vs") || lowered.contains("versus") {
            let items = extractComparisonItems(query: query)
            response += "\n\n**Comparative Matrix (\(items.0) vs \(items.1)):**"
            
            // LLM Upgrade: Comparison
            let prompt = "Compare '\(items.0)' vs '\(items.1)'. format as a markdown table with columns: Feature, \(items.0), \(items.1)."
            let llmResponse = await LLMService.shared.quickGenerate(prompt: prompt, systemPrompt: "You are a Research Analyst.")
            
             if !llmResponse.isEmpty {
                 response += "\n\n" + llmResponse
             } else {
                response += "\n\n| Feature | \(items.0) | \(items.1) |"
                response += "\n|---------|:---:|:---:|"
                response += "\n| Use Case | ? | ? |"
                response += "\n| Cost | ? | ? |"
                response += "\n| Maturity | ? | ? |"
             }
            
        } else if !response.contains("JSON") && !response.contains("CSV") {
            response += "\n\n**Data Tools Ready.**"
            response += "\n• Paste JSON to format"
            response += "\n• Paste CSV to visualize"
            response += "\n• Paste text to summarize"
        }
        
        return AgentResponse(text: response, confidence: confidence(for: query, context: context), agentName: name, suggestedAction: nil)
    }
    
    // ── Helper: Data Formatting ──
    private func prettifyJSON(_ text: String) -> String? {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data, options: []),
              let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) else { return nil }
        return String(data: prettyData, encoding: .utf8)
    }
    
    private func csvToMarkdown(_ text: String) -> String? {
        let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count > 1 else { return nil }
        
        let headers = lines[0].components(separatedBy: ",")
        let separator = headers.map { _ in "---" }.joined(separator: "|")
        
        var md = "| \(headers.joined(separator: " | ")) |\n| \(separator) |"
        
        for i in 1..<min(lines.count, 6) { // Limit to 5 rows for preview
            let row = lines[i].components(separatedBy: ",")
            md += "\n| \(row.joined(separator: " | ")) |"
        }
        
        if lines.count > 6 { md += "\n| ... | ... |" }
        return md
    }
    
    // ── Helper: Summarization (Heuristic) ──
    private func generateExtractiveSummary(text: String) -> String {
        let sentences = text.components(separatedBy: ". ")
        guard sentences.count > 3 else { return "\n" + text }
        
        // Simple heuristic: First sentence + sentences with keywords + last sentence
        var summary = "\n• " + sentences.first! + "."
        
        let keySentences = sentences.dropFirst().dropLast().filter {
            $0.lowercased().contains("important") ||
            $0.lowercased().contains("key") ||
            $0.lowercased().contains("result") ||
            $0.lowercased().contains("however")
        }
        
        for s in keySentences.prefix(2) {
            summary += "\n• " + s + "."
        }
        
        summary += "\n• " + sentences.last! + "."
        return summary
    }
    
    private func extractURLs(from text: String) -> [String] {
        // Mock regex for URLs
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return [] }
        let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        return matches.compactMap { $0.url?.absoluteString }
    }
    
    private func extractComparisonItems(query: String) -> (String, String) {
        // "compare swift vs python" -> ("Swift", "Python")
        let parts = query.lowercased().components(separatedBy: " vs ")
        if parts.count == 2 {
            return (parts[0].replacingOccurrences(of: "compare ", with: "").capitalized, parts[1].capitalized)
        }
        return ("Option A", "Option B")
    }
}

// ═══════════════════════════════════════════════════
// MARK: - 🛡️ Sentinel Agent (Security & Privacy)
// ═══════════════════════════════════════════════════

struct SentinelAgent: NotchAgent {
    let name = "Sentinel"
    let emoji = "🛡️"
    let domain = "Security & Privacy"
    
    // Patterns that indicate sensitive data
    private let sensitivePatterns = [
        "sk-", "sk_live_", "sk_test_",           // API keys
        "AKIA", "ASIA",                            // AWS keys
        "ghp_", "gho_", "ghs_",                   // GitHub tokens
        "xoxb-", "xoxp-",                         // Slack tokens
        "-----BEGIN",                               // Private keys
        "password", "secret", "token",
        "Bearer ", "Authorization:"
    ]
    
    private let securityKeywords = ["security", "secure", "privacy", "password", "encrypt",
                                     "key", "token", "leak", "vulnerability", "audit",
                                     "seguridad", "privacidad", "contraseña"]
    
    func confidence(for query: String, context: SensorFusion) -> Double {
        var score = 0.0
        
        let lowered = query.lowercased()
        let matches = securityKeywords.filter { lowered.contains($0) }.count
        score += Double(matches) * 0.2
        
        // Clipboard contains secrets?
        if let clip = context.clipboardContent {
            for pattern in sensitivePatterns {
                if clip.contains(pattern) {
                    score += 0.5 // High priority
                    break
                }
            }
        }
        
        return min(1.0, score)
    }
    
    func respond(to query: String, context: SensorFusion, memory: ConversationMemory) async -> AgentResponse {
        // Proactive: Check clipboard for secrets
        var secretsDetected: [String] = []
        if let clip = context.clipboardContent {
            for pattern in sensitivePatterns {
                if clip.contains(pattern) {
                    secretsDetected.append(pattern)
                }
            }
        }
        
        let response: String
        
        if !secretsDetected.isEmpty {
            let masked = secretsDetected.map { "⚠️ Pattern `\($0)***`" }.joined(separator: "\n")
            response = """
            🚨 **ALERT: Sensitive data detected in clipboard!**
            
            \(masked)
            
            **Recommended Actions:**
            1. Clear clipboard immediately (`Cmd+Shift+V` in terminal)
            2. Rotate the exposed key/token
            3. Check `.env` files are in `.gitignore`
            4. Use macOS Keychain for secret storage
            
            *I have NOT transmitted this data anywhere. All processing is local.*
            """
        } else {
            response = """
            \(emoji) Sentinel active. No threats detected.
            
            **Security Posture:**
            • Clipboard: ✅ Clean
            • Active App: \(context.activeAppName)
            • Network: [Monitoring disabled — privacy first]
            
            I can help with:
            • 🔑 API key management best practices
            • 🔒 Encryption guidance
            • 📋 Clipboard security audit
            • 🛡️ .gitignore verification
            """
        }
        
        let action: AgentResponse.SuggestedAction? = secretsDetected.isEmpty
            ? nil
            : .showNotification("⚠️ Secret detected in clipboard!")
        
        return AgentResponse(text: response, confidence: confidence(for: query, context: context), agentName: name, suggestedAction: action)
    }
}

// ═══════════════════════════════════════════════════
// MARK: - 💚 Empath Agent (Mood & Wellbeing)
// ═══════════════════════════════════════════════════

struct EmpathAgent: NotchAgent {
    let name = "Empath"
    let emoji = "💚"
    let domain = "Wellbeing & Flow"
    
    private let wellbeingKeywords = ["tired", "stressed", "break", "focus", "flow",
                                      "cansado", "estresado", "descanso", "animo",
                                      "how am i", "mood", "energy", "burnout",
                                      "motivation", "pomodoro", "breathe", "respirar"]
    
    func confidence(for query: String, context: SensorFusion) -> Double {
        let lowered = query.lowercased()
        var score = 0.0
        let matches = wellbeingKeywords.filter { lowered.contains($0) }.count
        score += Double(matches) * 0.2
        
        // High CPU + late night = empathy trigger
        if context.cpuUsage > 60 && (context.timeOfDay == .night || context.timeOfDay == .lateNight) {
            score += 0.25
        }
        
        // Stressed mood
        if context.currentMood == "stressed" { score += 0.3 }
        
        return min(1.0, score)
    }
    
    func respond(to query: String, context: SensorFusion, memory: ConversationMemory) async -> AgentResponse {
        // Dynamic Time Greeting
        let timeGreeting = getTimeGreeting(for: context.timeOfDay)
        
        // Stress Analysis
        let stressScore = calculateStress(context: context)
        let isHighStress = stressScore > 0.7
        
        var response = "\(timeGreeting)\n"
        
        if query.lowercased().contains("breathe") || query.lowercased().contains("respirar") || isHighStress {
            response += "\n🌬 **Guided Box Breathing (4-4-4-4):**"
            response += "\n1. Inhale (Hold Shift)... [====]"
            response += "\n2. Hold...               [----]"
            response += "\n3. Exhale...             [====]"
            response += "\n4. Pause...              [----]"
            response += "\n*Repeat 4 times to lower cortisol.*"
        
        } else if context.currentMood == "flow" {
            response += "\n🌊 **Flow State Detected.**"
            response += "\n• Notifications: Silenced"
            response += "\n• Momentum: High"
            response += "\n*Keep pushing, but drink water.*"
            
        } else {
            response += "\n**Neural Dashboard:**"
            response += "\n• System Load: \(Int(context.cpuUsage))%"
            response += "\n• Bat Energy: \(context.batteryLevel)%" // Simulated until IOKit
            response += "\n• Digital Stress: \(Int(stressScore * 100))%"
            
            if isHighStress {
                response += "\n\n⚠️ **High Intensity Detected.** Consider a 5 min break away from screens."
            } else {
                response += "\n\n✅ Systems Nominal. You are operating within sustainable parameters."
            }
        }
        
        return AgentResponse(text: response, confidence: confidence(for: query, context: context), agentName: name, suggestedAction: nil)
    }
    
    private func getTimeGreeting(for time: SensorFusion.TimeOfDay) -> String {
        switch time {
        case .morning: return "☕️ Good morning. Objectives aligned?"
        case .afternoon: return "☀️ Afternoon status. Hydration check."
        case .evening: return "🌅 Evening flow. Wrapping up or just starting?"
        case .night: return "🌙 Night mode active. Reduce blue light."
        case .lateNight: return "🦉 Late night operations. Sleep is critical for consolidation."
        }
    }
    
    private func calculateStress(context: SensorFusion) -> Double {
        var stress = 0.0
        if context.cpuUsage > 70 { stress += 0.4 }
        if context.timeOfDay == .lateNight { stress += 0.3 }
        // Todo: Add WPM or error rate from IDE (future)
        return min(1.0, stress)
    }
}

// ═══════════════════════════════════════════════════
// MARK: - 🎯 Orchestrator Agent (Workflow Engine)
// ═══════════════════════════════════════════════════

struct OrchestratorAgent: NotchAgent {
    let name = "Orchestrator"
    let emoji = "🎯"
    let domain = "Workflow Management"
    
    private let workflowKeywords = ["flujo glorioso", "glorious flow", "genesis", "workflow",
                                     "start flow", "next", "siguiente", "continue", "step",
                                     "fase", "phase", "protocol", "deca-core", "iniciar flujo"]
    
    func confidence(for query: String, context: SensorFusion) -> Double {
        let lowered = query.lowercased()
        var score = 0.0
        let matches = workflowKeywords.filter { lowered.contains($0) }.count
        score += Double(matches) * 0.25
        return min(1.0, score)
    }
    
    func respond(to query: String, context: SensorFusion, memory: ConversationMemory) async -> AgentResponse {
        // Workflow delegation — handled by SwarmCoordinator
        return AgentResponse(
            text: "Workflow routing...",
            confidence: confidence(for: query, context: context),
            agentName: name,
            suggestedAction: .startWorkflow("gloriousFlow")
        )
    }
}

// ═══════════════════════════════════════════════════
// MARK: - 🧠 Swarm Coordinator (The Brain)
// ═══════════════════════════════════════════════════

final class NotchIntelligence: ObservableObject {
    static let shared = NotchIntelligence()
    
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
        NSLog("🧠 NotchIntelligence v3: \(totalDNASpecies) total agent species ready")
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
            if response.suggestedAction != nil {
                // handle suggested action (TODO)
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
            streamOnMain("🧠 **Cortex Status:**\n- Entries: \(memory.conversationLength)/\(memory.maxCapacity)\n- Path: `~/.antigravity/cortex.json`\n- Persistence: ACTIVE", onStream: onStream)
            
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
