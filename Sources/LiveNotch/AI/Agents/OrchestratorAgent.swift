import SwiftUI

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
