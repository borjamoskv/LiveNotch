import SwiftUI

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
        if c.contains("todo:") || c.contains("f_ixme") { issues.append("• 📌 Technical debt markers found") }
        
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
