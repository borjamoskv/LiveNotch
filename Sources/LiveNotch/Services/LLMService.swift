import Foundation

// ═══════════════════════════════════════════════════
// MARK: - 🧠 LLM Service — Local Ollama Integration
// ═══════════════════════════════════════════════════
// Connects to a local Ollama instance for real AI inference.
// Falls back gracefully when Ollama is unavailable.

@MainActor
final class LLMService: ObservableObject {
    static let shared = LLMService()
    private let log = NotchLog.make("LLMService")
    
    
    // ── Connection State ──
    @Published var isConnected: Bool = false
    @Published var activeModel: String = ""
    @Published var isGenerating: Bool = false
    
    // ── Configuration ──
    private let baseURL = "http://localhost:11434"
    
    // Dynamic Model State
    @Published var availableModels: [String] = []
    
    // Preferred Model Order (Priority)
    private let preferredModels = [
        "deepseek-r1:7b", "deepseek-coder:6.7b", "qwen2.5:7b", "qwen2.5:3b",
        "llama3", "mistral", "gemma:2b"
    ]
    
    private init() {
        Task { await checkConnection() }
    }
    
    // ═══════════════════════════════════════════════
    // MARK: - Connection Health
    // ═══════════════════════════════════════════════
    
    func checkConnection() async {
        guard let url = URL(string: "\(baseURL)/api/tags") else {
            isConnected = false
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                isConnected = false
                return
            }
            
            // Parse available models
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let models = json["models"] as? [[String: Any]] {
                
                // Extract and clean model names (remove :latest if present to match against prefixes if needed, but keeping full names is safer for API)
                let modelNames = models.compactMap { $0["name"] as? String }
                self.availableModels = modelNames
                
                // Select Best Model
                if let bestMatch = preferredModels.first(where: { pref in modelNames.contains(where: { $0.contains(pref) }) }) {
                    // Find the actual full name in the list that matches the preference
                    self.activeModel = modelNames.first(where: { $0.contains(bestMatch) }) ?? modelNames.first ?? ""
                } else {
                    self.activeModel = modelNames.first ?? ""
                }
                
                isConnected = !modelNames.isEmpty
                
                if isConnected {
                    log.info("Connected to Ollama — Active: \(activeModel) (Available: \(modelNames.count))")
                } else {
                    log.warning("Connected to Ollama but NO models found.")
                }
            }
        } catch {
            isConnected = false
            log.error("Ollama not available — \(error.localizedDescription)")
        }
    }
    
    // ═══════════════════════════════════════════════
    // MARK: - Generation API
    // ═══════════════════════════════════════════════
    
    /// Generate a response with streaming callback
    func generate(
        prompt: String,
        systemPrompt: String = "",
        onPartial: @escaping (String) -> Void,
        onComplete: @escaping (String) -> Void
    ) async {
        guard isConnected, !activeModel.isEmpty else {
            onComplete("")
            return
        }
        
        let model = activeModel
        
        guard let url = URL(string: "\(baseURL)/api/generate") else {
            onComplete("")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60
        
        let body: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "system": systemPrompt,
            "stream": true,
            "options": [
                "temperature": 0.7,
                "top_p": 0.9,
                "num_predict": 512
            ]
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            onComplete("")
            return
        }
        request.httpBody = jsonData
        
        isGenerating = true
        var fullResponse = ""
        
        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                isGenerating = false
                onComplete("")
                return
            }
            
            // Stream NDJSON lines
            for try await line in bytes.lines {
                guard let lineData = line.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                      let responseText = json["response"] as? String else {
                    continue
                }
                
                fullResponse += responseText
                onPartial(fullResponse)
                
                // Check if done
                if let done = json["done"] as? Bool, done {
                    break
                }
            }
        } catch {
            log.error("Generation error — \(error.localizedDescription)")
            // On error, mark disconnected and retry connection later
            isConnected = false
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5s retry
                await checkConnection()
            }
        }
        
        isGenerating = false
        onComplete(fullResponse)
    }
    
    // ═══════════════════════════════════════════════
    // MARK: - Convenience Methods
    // ═══════════════════════════════════════════════
    
    /// Quick single-shot generation (no streaming)
    func quickGenerate(prompt: String, systemPrompt: String = "") async -> String {
        guard isConnected else { return "" }
        
        var result = ""
        await generate(
            prompt: prompt,
            systemPrompt: systemPrompt,
            onPartial: { _ in },
            onComplete: { result = $0 }
        )
        return result
    }
    
    /// Build a system prompt with context
    func buildSystemPrompt(agentDomain: String, sensorContext: String) -> String {
        """
        You are Naroa, an AI agent embedded in a macOS notch overlay.
        Your domain: \(agentDomain)
        
        Current context:
        \(sensorContext)
        
        Rules:
        - Be extremely concise (1-3 sentences max)
        - Use technical language when appropriate
        - Never say "I'm an AI" or similar disclaimers
        - Respond in the user's language
        - If uncertain, say so briefly
        """
    }
}
