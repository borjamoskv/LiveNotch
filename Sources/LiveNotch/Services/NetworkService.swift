import Foundation
import Combine

// ═══════════════════════════════════════════════════
// MARK: - 🌐 NETWORK CORE
// ═══════════════════════════════════════════════════
// Foundation for Laravel/Moskv API integration.
// Currently serves as a structural placeholder and utility belt.

enum NetworkError: Error {
    case invalidURL
    case noData
    case decodingError
    case serverError(statusCode: Int)
    case unknown(Error)
}

struct Endpoint {
    let path: String
    let method: String
    let body: Data?
    
    static func get(path: String) -> Endpoint {
        Endpoint(path: path, method: "GET", body: nil)
    }
    
    static func post(path: String, body: Encodable) -> Endpoint {
        let data = try? JSONEncoder().encode(body)
        return Endpoint(path: path, method: "POST", body: data)
    }
}

final class NetworkService: ObservableObject {
    static let shared = NetworkService()
    
    // Configuration
    // SECURITY: Base URL configurable via UserDefaults in production
    private let baseURL = "https://moskv.dev/api/v1"
    
    // Status
    @Published var serverStatus: ServerStatus = .unknown
    @Published var lastLatency: Double = 0.0
    
    enum ServerStatus {
        case unknown
        case online
        case degraded
        case offline
    }
    
    private init() {
        // Start periodic health check
        startHealthCheck()
    }
    
    /// Telemetry Pulse (Ping)
    func pulse() async -> Bool {
        let start = Date()
        // Simulate network call
        try? await Task.sleep(nanoseconds: 150_000_000) // 150ms
        let duration = Date().timeIntervalSince(start) * 1000
        
        DispatchQueue.main.async {
            self.lastLatency = duration
            self.serverStatus = .online
        }
        return true
    }
    
    private var healthCheckTimer: Timer?

    private func startHealthCheck() {
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task {
                _ = await self?.pulse()
            }
        }
        // Initial check
        Task { _ = await pulse() }
    }
    
    deinit {
        healthCheckTimer?.invalidate()
    }
    
    /// Generic async fetch
    func fetch<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        guard let url = URL(string: baseURL + endpoint.path) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method
        request.httpBody = endpoint.body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.unknown(NSError(domain: "Invalid Response", code: 0))
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw NetworkError.serverError(statusCode: httpResponse.statusCode)
            }
            
            let decoded = try JSONDecoder().decode(T.self, from: data)
            return decoded
            
        } catch {
            DispatchQueue.main.async { self.serverStatus = .offline }
            throw NetworkError.unknown(error)
        }
    }
}

// ═══════════════════════════════════════════════════
// MARK: - API Definition
// ═══════════════════════════════════════════════════

enum MoskvAPI {
    case status
    case telemetry(payload: TelemetryPayload)
    
    var endpoint: Endpoint {
        switch self {
        case .status:
            return Endpoint.get(path: "/status")
        case .telemetry(let payload):
            return Endpoint(path: "/telemetry", method: "POST", body: try? JSONEncoder().encode(payload))
        }
    }
}

/// Type-safe telemetry payload
struct TelemetryPayload: Encodable {
    let cpuUsage: Double
    let memoryUsage: Double
    let batteryLevel: Int
    let activeApp: String
    let timestamp: Date
}
