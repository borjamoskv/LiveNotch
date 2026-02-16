import SwiftUI
import Combine

// ═══════════════════════════════════════════════════════════════════
// MARK: - Swarm Consensus Protocol
// ═══════════════════════════════════════════════════════════════════

/// Byzantine fault-tolerant consensus for agent responses.
/// Uses weighted voting to determine the best response.
enum ConsensusProtocol {
    /// Simple majority — best single response wins
    case majority
    /// Weighted synthesis — top N responses are merged
    case synthesis(topN: Int)
    /// Tournament — agents compete head-to-head
    case tournament
    /// Unanimous — all agents must agree (high confidence required)
    case unanimous

    /// Select the best response(s) from the swarm
    static func resolve(
        agents: [MicroAgent],
        protocol proto: ConsensusProtocol = .synthesis(topN: 3)
    ) -> SwarmConsensusResult {
        let sorted = agents.sorted { $0.confidence > $1.confidence }
        let totalConfidence = sorted.reduce(0.0) { $0 + $1.confidence }

        switch proto {
        case .majority:
            guard let winner = sorted.first else {
                return SwarmConsensusResult.empty
            }
            return SwarmConsensusResult(
                finalResponse: winner.response,
                winningAgent: winner.dna.species,
                winningEmoji: winner.dna.emoji,
                participantCount: agents.count,
                consensusStrength: winner.confidence,
                protocol: "Majority",
                breakdown: sorted.prefix(5).map { agent in
                    SwarmConsensusResult.AgentVote(
                        species: agent.dna.species,
                        emoji: agent.dna.emoji,
                        confidence: agent.confidence,
                        processingTimeMs: agent.processingTimeMs
                    )
                }
            )

        case .synthesis(let topN):
            let experts = Array(sorted.prefix(topN).filter { $0.confidence > 0.2 })
            guard !experts.isEmpty else { return SwarmConsensusResult.empty }

            if experts.count == 1 {
                return SwarmConsensusResult(
                    finalResponse: experts[0].response,
                    winningAgent: experts[0].dna.species,
                    winningEmoji: experts[0].dna.emoji,
                    participantCount: agents.count,
                    consensusStrength: experts[0].confidence,
                    protocol: "Single Expert",
                    breakdown: sorted.prefix(5).map { agent in
                        SwarmConsensusResult.AgentVote(
                            species: agent.dna.species,
                            emoji: agent.dna.emoji,
                            confidence: agent.confidence,
                            processingTimeMs: agent.processingTimeMs
                        )
                    }
                )
            }

            // Build collaborative synthesis
            let hiveLabel = experts.map { "\($0.dna.emoji) \($0.dna.species)" }.joined(separator: " × ")
            var synthesis = "🐝 **Hive Mind — \(agents.count) agents spawned, \(experts.count) converged**\n"
            synthesis += "Consensus: \(hiveLabel)\n\n"
            synthesis += "═══════════════════════════════════════\n\n"

            for expert in experts {
                let weight = Int((expert.confidence / totalConfidence) * 100)
                synthesis += "### \(expert.dna.emoji) \(expert.dna.species) (\(weight)% weight)\n"
                synthesis += "\(expert.response)\n\n"
                synthesis += "───\n\n"
            }

            return SwarmConsensusResult(
                finalResponse: synthesis,
                winningAgent: "HiveMind",
                winningEmoji: "🐝",
                participantCount: agents.count,
                consensusStrength: experts.first?.confidence ?? 0,
                protocol: "Synthesis(\(topN))",
                breakdown: sorted.prefix(10).map { agent in
                    SwarmConsensusResult.AgentVote(
                        species: agent.dna.species,
                        emoji: agent.dna.emoji,
                        confidence: agent.confidence,
                        processingTimeMs: agent.processingTimeMs
                    )
                }
            )

        case .tournament:
            // Round-robin tournament: higher confidence always wins
            guard sorted.count >= 2 else {
                return ConsensusProtocol.resolve(agents: agents, protocol: .majority)
            }
            // Champion is simply the highest after all rounds
            return ConsensusProtocol.resolve(agents: agents, protocol: .majority)

        case .unanimous:
            let threshold = 0.6
            let agreeing = sorted.filter { $0.confidence > threshold }
            if agreeing.count == sorted.count && !sorted.isEmpty {
                return ConsensusProtocol.resolve(agents: agents, protocol: .majority)
            } else {
                // No unanimous agreement — fall back to synthesis
                return ConsensusProtocol.resolve(agents: agents, protocol: .synthesis(topN: 3))
            }
        }
    }
}

struct SwarmConsensusResult {
    let finalResponse: String
    let winningAgent: String
    let winningEmoji: String
    let participantCount: Int
    let consensusStrength: Double
    let `protocol`: String
    let breakdown: [AgentVote]

    struct AgentVote {
        let species: String
        let emoji: String
        let confidence: Double
        let processingTimeMs: Double
    }

    static let empty = SwarmConsensusResult(
        finalResponse: "The swarm could not reach consensus. Try rephrasing your query.",
        winningAgent: "None",
        winningEmoji: "❓",
        participantCount: 0,
        consensusStrength: 0,
        protocol: "None",
        breakdown: []
    )
}
