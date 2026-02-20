import SwiftUI
import Combine

// ═══════════════════════════════════════════════════
// MARK: - 🧠 CortexController — The Memory Bridge
// ═══════════════════════════════════════════════════
// Connects the notch to the CORTEX REST API.
// Polls for ghosts, health state, and exposes
// store/search/resolve operations.
//
// Pattern: Features/ controller, wired via NotchViewModel.
// API: localhost:8000 (CORTEX Sovereign Memory API)

private let cortexLog = NotchLog.make("CortexController")

@MainActor
final class CortexController: ObservableObject {
    
    // ── Configuration ──
    private let baseURL: String
    private var apiKey: String?
    private var pollTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // ── Published State ──
    @Published var connectionState: CortexConnectionState = .disconnected
    @Published var ghosts: [CortexFact] = []
    @Published var recentFacts: [CortexFact] = []
    @Published var ghostCount: Int = 0
    @Published var totalFacts: Int = 0
    @Published var projects: [String] = []
    @Published var version: String = "?"
    @Published var searchResults: [CortexSearchResult] = []
    @Published var isSearching: Bool = false
    @Published var lastError: String?
    
    // ── Quick Store State ──
    @Published var quickStoreProject: String = "cortex"
    @Published var quickStoreContent: String = ""
    @Published var quickStoreType: String = "ghost"
    @Published var isStoring: Bool = false
    @Published var lastStoreResult: String?
    
    // ── Ghost Toast Callback ──
    var onNewGhosts: ((Int) -> Void)?  // Called with count of NEW ghosts
    private var previousGhostCount: Int = 0
    
    // ── Search State ──
    @Published var searchQuery: String = ""
    
    // ── Metrics ──
    @Published var lastPollTime: Date?
    @Published var consecutiveFailures: Int = 0
    
    // ════════════════════════════════════════
    // MARK: - Init
    // ════════════════════════════════════════
    
    init(baseURL: String = "http://localhost:8000", apiKey: String? = nil) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        cortexLog.started("CortexController")
        startPolling()
    }
    
    deinit {
        pollTimer?.invalidate()
    }
    
    // ════════════════════════════════════════
    // MARK: - Polling
    // ════════════════════════════════════════
    
    /// Start heartbeat polling — checks health + ghost count every 30s
    private func startPolling() {
        // Initial fetch
        Task { await refresh() }
        
        // Recurring poll
        pollTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refresh()
            }
        }
    }
    
    /// Full refresh: health + ghosts
    func refresh() async {
        await checkHealth()
        await fetchGhosts()
    }
    
    // ════════════════════════════════════════
    // MARK: - Health Check
    // ════════════════════════════════════════
    
    func checkHealth() async {
        connectionState = .connecting
        
        guard let url = URL(string: "\(baseURL)/health") else {
            connectionState = .error
            cortexLog.error("Invalid CORTEX URL")
            return
        }
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5
            addAuthHeaders(&request)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                connectionState = .error
                consecutiveFailures += 1
                cortexLog.warning("CORTEX health check failed: HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                return
            }
            
            let health = try JSONDecoder().decode(CortexHealth.self, from: data)
            version = health.version ?? "?"
            connectionState = .connected
            consecutiveFailures = 0
            lastPollTime = Date()
            
            cortexLog.debug("CORTEX health OK — v\(version)")
            
        } catch {
            connectionState = .disconnected
            consecutiveFailures += 1
            cortexLog.warning("CORTEX unreachable: \(error.localizedDescription)")
        }
    }
    
    // ════════════════════════════════════════
    // MARK: - Fetch Ghosts
    // ════════════════════════════════════════
    
    func fetchGhosts() async {
        guard connectionState == .connected else { return }
        
        guard let url = URL(string: "\(baseURL)/v1/projects/live-notch/facts?limit=100") else { return }
        
        do {
            var request = URLRequest(url: url)
            addAuthHeaders(&request)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                cortexLog.warning("Failed to fetch ghosts")
                return
            }
            
            let allFacts = try JSONDecoder().decode([CortexFact].self, from: data)
            ghosts = allFacts.filter { $0.fact_type == "ghost" }
            ghostCount = ghosts.count
            
            // Detect NEW ghosts → fire toast callback
            if ghostCount > previousGhostCount && previousGhostCount > 0 {
                let newCount = ghostCount - previousGhostCount
                onNewGhosts?(newCount)
            }
            previousGhostCount = ghostCount
            
            // Extract unique projects
            projects = Array(Set(ghosts.map { $0.project })).sorted()
            
            cortexLog.debug("Fetched \(ghostCount) ghosts across \(projects.count) projects")
            
        } catch {
            cortexLog.warning("Ghost fetch error: \(error.localizedDescription)")
        }
    }
    
    // ════════════════════════════════════════
    // MARK: - Search
    // ════════════════════════════════════════
    
    func search(query: String) async {
        guard connectionState == .connected, !query.isEmpty else { return }
        
        isSearching = true
        searchQuery = query
        
        guard let url = URL(string: "\(baseURL)/v1/search") else {
            isSearching = false
            return
        }
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            addAuthHeaders(&request)
            
            let body = CortexSearchRequest(query: query, project: nil, type: nil, limit: 10)
            request.httpBody = try JSONEncoder().encode(body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                isSearching = false
                cortexLog.warning("Search failed")
                return
            }
            
            let searchResponse = try JSONDecoder().decode([CortexSearchResult].self, from: data)
            searchResults = searchResponse
            isSearching = false
            
            cortexLog.debug("Search '\(query)': \(searchResults.count) results")
            
        } catch {
            isSearching = false
            cortexLog.warning("Search error: \(error.localizedDescription)")
        }
    }
    
    // ════════════════════════════════════════
    // MARK: - Quick Store
    // ════════════════════════════════════════
    
    func store(project: String, content: String, type: String) async -> Bool {
        guard connectionState == .connected, !content.isEmpty else { return false }
        
        isStoring = true
        
        guard let url = URL(string: "\(baseURL)/v1/facts") else {
            isStoring = false
            return false
        }
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            addAuthHeaders(&request)
            
            let body = CortexStoreRequest(project: project, content: content, fact_type: type, tags: nil)
            request.httpBody = try JSONEncoder().encode(body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...201).contains(httpResponse.statusCode) else {
                isStoring = false
                lastStoreResult = "Error storing fact"
                cortexLog.warning("Store failed")
                return false
            }
            
            let storeResponse = try JSONDecoder().decode(CortexStoreResponse.self, from: data)
            isStoring = false
            lastStoreResult = storeResponse.message ?? "Stored"
            
            cortexLog.info("Stored fact in '\(project)' [\(type)]")
            
            // Refresh ghosts if we stored a ghost
            if type == "ghost" {
                await fetchGhosts()
            }
            
            return true
            
        } catch {
            isStoring = false
            lastStoreResult = "Error: \(error.localizedDescription)"
            cortexLog.error("Store error: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Quick store from the notch — uses current quickStore* state
    func quickStore() async -> Bool {
        let result = await store(
            project: quickStoreProject,
            content: quickStoreContent,
            type: quickStoreType
        )
        if result {
            quickStoreContent = ""
        }
        return result
    }
    
    // ════════════════════════════════════════
    // MARK: - Resolve Ghost
    // ════════════════════════════════════════
    
    func resolveGhost(_ ghost: CortexFact) async -> Bool {
        guard connectionState == .connected else { return false }
        
        guard let url = URL(string: "\(baseURL)/v1/facts/\(ghost.id)") else { return false }
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            addAuthHeaders(&request)
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...204).contains(httpResponse.statusCode) else {
                cortexLog.warning("Failed to resolve ghost: \(ghost.id)")
                return false
            }
            
            // Remove from local list
            ghosts.removeAll { $0.id == ghost.id }
            ghostCount = ghosts.count
            
            cortexLog.info("Resolved ghost: \(ghost.id) in \(ghost.project)")
            return true
            
        } catch {
            cortexLog.error("Resolve error: \(error.localizedDescription)")
            return false
        }
    }
    
    // ════════════════════════════════════════
    // MARK: - Helpers
    // ════════════════════════════════════════
    
    private func addAuthHeaders(_ request: inout URLRequest) {
        if let key = apiKey {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
    }
    
    /// Ghost urgency level for BioLum integration
    var ghostUrgency: Double {
        switch ghostCount {
        case 0: return 0.0
        case 1...5: return 0.3
        case 6...10: return 0.6
        default: return 1.0
        }
    }
    
    /// Unique projects with ghost counts
    var ghostsByProject: [(project: String, count: Int)] {
        let grouped = Dictionary(grouping: ghosts) { $0.project }
        return grouped.map { (project: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }
}
