import Foundation

// ═══════════════════════════════════════════════════
// MARK: - Conversation Memory
// ═══════════════════════════════════════════════════

class ConversationMemory {
    private let log = NotchLog.make("ConversationMemory")
    struct Exchange: Codable {
    
        let query: String
        let response: String
        let agent: String
        let timestamp: Date
    }
    
    private(set) var exchanges: [Exchange] = []
    let maxCapacity: Int = 50
    init() {
        // Now using CORTEX v4 REST API
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
        // Encode only the last exchange to avoid over-posting
        guard let exchange = exchanges.last else { return }
        
        Task {
            do {
                let json = try JSONEncoder().encode(exchange)
                guard let content = String(data: json, encoding: .utf8) else { return }
                
                guard let url = URL(string: "http://localhost:8000/v1/facts") else { return }
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let body: [String: Any] = [
                    "project": "live-notch",
                    "content": content,
                    "fact_type": "conversation",
                    "tags": ["memory", "live-notch"]
                ]
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                
                let (_, response) = try await URLSession.shared.data(for: request)
                if let httpResp = response as? HTTPURLResponse, httpResp.statusCode >= 200, httpResp.statusCode < 300 {
                    self.log.debug("Conversation exchange saved to CORTEX v4 API")
                } else {
                    self.log.warning("CORTEX API memory save returned non-200")
                }
            } catch {
                self.log.error("CORTEX v4 Store Failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func loadFromCortex() {
        Task {
            do {
                guard let url = URL(string: "http://localhost:8000/v1/projects/live-notch/facts?limit=25") else { return }
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
                    self.log.info("CORTEX Memory Load returned non-200 (App isolated/offline?)")
                    return
                }
                
                // Assuming FactResponse is decoded from the `/facts` endpoint. 
                // We're expecting `content` to hold the JSON string of `Exchange`.
                // For simplicity, we decode manually if we need to map back to `ConversationMemory.Exchange`.
                struct MinimalFact: Codable {
                    let fact_type: String
                    let content: String
                }
                
                let facts = try JSONDecoder().decode([MinimalFact].self, from: data)
                let convoFacts = facts.filter { $0.fact_type == "conversation" }
                
                var loadedExchanges: [Exchange] = []
                for fact in convoFacts {
                    if let contentData = fact.content.data(using: .utf8),
                       let exchange = try? JSONDecoder().decode(Exchange.self, from: contentData) {
                        loadedExchanges.append(exchange)
                    }
                }
                
                DispatchQueue.main.async {
                    // CORTEX returns latest first typically, so we reverse it to replay conversation
                    self.exchanges = loadedExchanges.reversed()
                }
            } catch {
                self.log.info("CORTEX Memory Load Failed: connection refused or unavailable")
            }
        }
    }
}
