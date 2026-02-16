import SwiftUI

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
        return "\n• Complementary: [Calculated Contrast]"
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
