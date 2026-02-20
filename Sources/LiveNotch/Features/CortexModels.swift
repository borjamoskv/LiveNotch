import Foundation

// ═══════════════════════════════════════════════════
// MARK: - 🧠 CORTEX Data Models
// ═══════════════════════════════════════════════════
// Data types for communicating with CORTEX REST API.
// Mirrors cortex.models (Python) on the Swift side.

// MARK: - Fact

struct CortexFact: Identifiable, Codable, Hashable {
    let id: Int
    let project: String
    let fact_type: String
    let content: String
    let created_at: String?
    let updated_at: String?
    let status: String?
    let tags: [String]?
    
    var type: String { fact_type }
    var isGhost: Bool { fact_type == "ghost" }
    var isDecision: Bool { fact_type == "decision" }
    var isError: Bool { fact_type == "error" }
    
    var typeIcon: String {
        switch fact_type {
        case "ghost": return "eye.fill"
        case "decision": return "checkmark.seal.fill"
        case "error": return "exclamationmark.triangle.fill"
        case "knowledge": return "book.fill"
        case "bridge": return "arrow.triangle.branch"
        case "rule": return "shield.fill"
        case "task": return "checklist"
        default: return "doc.fill"
        }
    }
    
    var typeColor: String {
        switch fact_type {
        case "ghost": return "purple"
        case "decision": return "green"
        case "error": return "red"
        case "knowledge": return "blue"
        case "bridge": return "cyan"
        case "rule": return "orange"
        case "task": return "yellow"
        default: return "gray"
        }
    }
}

// MARK: - Health

struct CortexHealth: Codable {
    let status: String?
    let engine: String?
    let version: String?
}

// MARK: - Search

struct CortexSearchRequest: Codable {
    let query: String
    let project: String?
    let type: String?
    let limit: Int?
}

struct CortexSearchResult: Identifiable, Codable {
    var id: String { content.prefix(32) + String(score ?? 0) }
    let content: String
    let project: String?
    let fact_type: String?
    let score: Double?
    let fact_id: Int?
    var type: String? { fact_type }
}

struct CortexSearchResponse: Codable {
    let results: [CortexSearchResult]?
    let query: String?
    let total: Int?
}

// MARK: - Store Request

struct CortexStoreRequest: Codable {
    let project: String
    let content: String
    let fact_type: String
    let tags: [String]?
}

// MARK: - Store Response

struct CortexStoreResponse: Codable {
    let fact_id: Int?
    let project: String?
    let message: String?
}

// MARK: - Facts List Response

struct CortexFactsResponse: Codable {
    let facts: [CortexFact]?
}

// MARK: - API Metrics

struct CortexMetrics: Codable {
    let content: String? // raw prometheus text
}

// MARK: - Connection State

enum CortexConnectionState: String {
    case connected = "connected"
    case disconnected = "disconnected"
    case connecting = "connecting"
    case error = "error"
    
    var icon: String {
        switch self {
        case .connected: return "bolt.fill"
        case .disconnected: return "bolt.slash.fill"
        case .connecting: return "bolt.ring.closed"
        case .error: return "exclamationmark.bolt.fill"
        }
    }
    
    var label: String {
        switch self {
        case .connected: return "CORTEX Online"
        case .disconnected: return "CORTEX Offline"
        case .connecting: return "Connecting..."
        case .error: return "CORTEX Error"
        }
    }
}
