import SwiftUI

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
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return [] }
        let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        return matches.compactMap { $0.url?.absoluteString }
    }
    
    private func extractComparisonItems(query: String) -> (String, String) {
        let parts = query.lowercased().components(separatedBy: " vs ")
        if parts.count == 2 {
            return (parts[0].replacingOccurrences(of: "compare ", with: "").capitalized, parts[1].capitalized)
        }
        return ("Option A", "Option B")
    }
}
