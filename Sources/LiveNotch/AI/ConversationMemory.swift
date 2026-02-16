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
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            do {
                let data = try JSONEncoder().encode(self.exchanges)
                try data.write(to: self.cortexPath, options: .atomic)
            } catch {
                self.log.error("Cortex Memory Save Failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func loadFromCortex() {
        do {
            let data = try Data(contentsOf: cortexPath)
            exchanges = try JSONDecoder().decode([Exchange].self, from: data)
        } catch {
            log.info("Cortex Memory Load Failed (New Cortex Created)")
        }
    }
}
