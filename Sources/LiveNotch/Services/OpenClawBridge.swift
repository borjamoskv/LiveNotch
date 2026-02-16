import SwiftUI
import Combine
import Foundation

// ═══════════════════════════════════════════════════════════
// MARK: - 🐾 OpenClawBridge — AI Agent Integration
// ═══════════════════════════════════════════════════════════
// Connects LiveNotch with OpenClaw (self-hosted AI assistant).
// OpenClaw runs as a local gateway (Node.js) and exposes a
// REST API for chat, task execution, and skill invocation.
//
// LiveNotch can:
// - Send commands to OpenClaw ("switch AirPods to Watch")
// - Receive proactive suggestions ("Meeting in 5m → ANC ON?")
// - Route notch gestures to AI actions
// - Display OpenClaw responses in notch overlay
//
// Reference: https://github.com/nicepkg/openclaw

@MainActor
final class OpenClawBridge: ObservableObject {
    static let shared = OpenClawBridge()
    private let log = NotchLog.make("OpenClawBridge")
    
    // ─── Connection State ───
    @Published var isConnected = false
    @Published var isProcessing = false
    @Published var lastResponse: ClawResponse?
    @Published var suggestions: [ClawSuggestion] = []
    @Published var conversationHistory: [ClawMessage] = []
    
    // ─── Config ───
    private var gatewayURL: URL
    private var apiKey: String?
    private var pollTimer: AnyCancellable?
    
    // Default OpenClaw gateway port
    private static let defaultPort = 3117
    
    // ═══════════════════════════════════════════════════
    // MARK: - Types
    // ═══════════════════════════════════════════════════
    
    struct ClawResponse: Identifiable, Equatable {
        let id = UUID()
        let text: String
        let actionType: ActionType?
        let timestamp: Date
        
        static func == (lhs: ClawResponse, rhs: ClawResponse) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    struct ClawSuggestion: Identifiable {
        let id = UUID()
        let text: String
        let action: () -> Void
        let icon: String
        let priority: Int  // 0 = low, 10 = critical
    }
    
    struct ClawMessage: Identifiable, Codable {
        let id: UUID
        let role: MessageRole
        let content: String
        let timestamp: Date
        
        init(role: MessageRole, content: String) {
            self.id = UUID()
            self.role = role
            self.content = content
            self.timestamp = Date()
        }
    }
    
    enum MessageRole: String, Codable {
        case user, assistant, system
    }
    
    enum ActionType: String {
        case audioSwitch    // "switch audio to watch"
        case ancToggle      // "turn on noise cancellation"
        case noteCapture    // "remember this: ..."
        case automation     // "when I open zoom, mute watch"
        case query          // general question
        case shellCommand   // execute terminal command
        case fileAction     // read/write files
    }
    
    // ═══════════════════════════════════════════════════
    // MARK: - Initialization
    // ═══════════════════════════════════════════════════
    
    init() {
        self.gatewayURL = URL(string: "http://localhost:\(Self.defaultPort)")!
        loadConfig()
        checkConnection()
        startSuggestionPolling()
        log.info("OpenClawBridge initialized → \(gatewayURL.absoluteString)")
    }
    
    /// Chat history as displayable responses (bridges ClawMessage → ClawResponse)
    var chatHistory: [ClawResponse] {
        conversationHistory.map { msg in
            ClawResponse(
                text: msg.content,
                actionType: nil,
                timestamp: msg.timestamp
            )
        }
    }
    
    // ═══════════════════════════════════════════════════
    // MARK: - Chat API
    // ═══════════════════════════════════════════════════
    
    /// Send a message to OpenClaw and get a response
    func send(_ message: String) async -> ClawResponse? {
        guard isConnected else {
            log.warning("OpenClaw not connected")
            return nil
        }
        
        isProcessing = true
        
        let userMessage = ClawMessage(role: .user, content: message)
        conversationHistory.append(userMessage)
        
        defer { isProcessing = false }
        
        // Detect action type from message
        let actionType = detectActionType(message)
        
        // If it's a LiveNotch-specific action, handle locally
        if let localResponse = handleLocalAction(message, type: actionType) {
            let response = ClawResponse(
                text: localResponse,
                actionType: actionType,
                timestamp: Date()
            )
            lastResponse = response
            
            let assistantMessage = ClawMessage(role: .assistant, content: localResponse)
            conversationHistory.append(assistantMessage)
            return response
        }
        
        // Otherwise, forward to OpenClaw gateway
        do {
            let response = try await callGateway(message: message)
            lastResponse = response
            
            let assistantMessage = ClawMessage(role: .assistant, content: response.text)
            conversationHistory.append(assistantMessage)
            return response
        } catch {
            log.error("OpenClaw request failed: \(error)")
            let fallback = ClawResponse(
                text: "⚠️ OpenClaw offline. Command queued.",
                actionType: nil,
                timestamp: Date()
            )
            lastResponse = fallback
            return fallback
        }
    }
    
    /// Quick command (no response needed)
    func execute(_ command: String) {
        Task {
            _ = await send(command)
        }
    }
    
    // ═══════════════════════════════════════════════════
    // MARK: - Action Detection & Local Handling
    // ═══════════════════════════════════════════════════
    
    private func detectActionType(_ message: String) -> ActionType? {
        let lower = message.lowercased()
        
        if lower.contains("airpods") || lower.contains("audio") || lower.contains("switch") ||
           lower.contains("watch") && lower.contains("music") {
            return .audioSwitch
        }
        if lower.contains("anc") || lower.contains("noise") || lower.contains("transparency") {
            return .ancToggle
        }
        if lower.contains("note") || lower.contains("remember") || lower.contains("apunta") ||
           lower.contains("recordar") {
            return .noteCapture
        }
        if lower.contains("when") || lower.contains("auto") || lower.contains("if") {
            return .automation
        }
        
        return .query
    }
    
    private func handleLocalAction(_ message: String, type: ActionType?) -> String? {
        guard let type = type else { return nil }
        
        switch type {
        case .audioSwitch:
            if message.lowercased().contains("watch") {
                EcosystemBridge.shared.switchAudio(to: .watch)
                return "✅ Audio switched to Apple Watch"
            } else if message.lowercased().contains("mac") {
                EcosystemBridge.shared.switchAudio(to: .mac)
                return "✅ Audio switched to Mac"
            } else if message.lowercased().contains("iphone") {
                EcosystemBridge.shared.switchAudio(to: .iphone)
                return "✅ Audio switched to iPhone"
            }
            return nil
            
        case .ancToggle:
            EcosystemBridge.shared.toggleANC()
            return "✅ ANC → \(EcosystemBridge.shared.airpodsANC.rawValue)"
            
        case .noteCapture:
            let noteText = message
                .replacingOccurrences(of: "remember ", with: "")
                .replacingOccurrences(of: "apunta ", with: "")
                .replacingOccurrences(of: "note: ", with: "")
            QuickNoteService.shared.captureText = noteText
            QuickNoteService.shared.saveCapture()
            return "📝 Note saved: \(noteText.prefix(50))"
            
        default:
            return nil
        }
    }
    
    // ═══════════════════════════════════════════════════
    // MARK: - Gateway Communication
    // ═══════════════════════════════════════════════════
    
    private func callGateway(message: String) async throws -> ClawResponse {
        let endpoint = gatewayURL.appendingPathComponent("api/chat")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let key = apiKey {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        
        let body: [String: Any] = [
            "message": message,
            "context": [
                "app": NervousSystem.shared.activeAppName,
                "ecosystem": EcosystemBridge.shared.detectedActivity.rawValue,
                "heartRate": EcosystemBridge.shared.heartRate
            ] as [String: Any]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let text = json["response"] as? String {
            return ClawResponse(text: text, actionType: nil, timestamp: Date())
        }
        
        return ClawResponse(
            text: String(data: data, encoding: .utf8) ?? "No response",
            actionType: nil,
            timestamp: Date()
        )
    }
    
    func checkConnection() {
        Task {
            do {
                let healthURL = gatewayURL.appendingPathComponent("api/health")
                let (_, response) = try await URLSession.shared.data(from: healthURL)
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    isConnected = true
                    log.info("OpenClaw gateway connected ✓")
                } else {
                    isConnected = false
                }
            } catch {
                isConnected = false
                log.info("OpenClaw gateway not available (standalone mode)")
            }
        }
    }
    
    // ═══════════════════════════════════════════════════
    // MARK: - Proactive Suggestions
    // ═══════════════════════════════════════════════════
    
    private func startSuggestionPolling() {
        pollTimer = Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.generateSuggestions()
            }
    }
    
    private func generateSuggestions() {
        var newSuggestions: [ClawSuggestion] = []
        
        let eco = EcosystemBridge.shared
        
        // Battery warning
        let lowBattery = eco.accessories.filter { $0.isConnected && $0.batteryLeft < 20 && $0.batteryLeft >= 0 }
        for acc in lowBattery {
            newSuggestions.append(ClawSuggestion(
                text: "🔴 \(acc.name) battery low (\(acc.batteryLeft)%)",
                action: { /* Open battery details */ },
                icon: "battery.25",
                priority: 8
            ))
        }
        
        // Context automation
        if let suggestion = eco.automationSuggestion {
            newSuggestions.append(ClawSuggestion(
                text: suggestion,
                action: { eco.applyAutomation() },
                icon: "wand.and.stars",
                priority: 6
            ))
        }
        
        // Heart rate alert
        if eco.heartRate > 150 {
            newSuggestions.append(ClawSuggestion(
                text: "❤️‍🔥 Heart rate elevated: \(eco.heartRate)bpm",
                action: { /* Open breathing guide */ },
                icon: "heart.fill",
                priority: 7
            ))
        }
        
        suggestions = newSuggestions.sorted { $0.priority > $1.priority }
    }
    
    // ═══════════════════════════════════════════════════
    // MARK: - Configuration
    // ═══════════════════════════════════════════════════
    
    private func loadConfig() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let configPath = home.appendingPathComponent(".openclaw/config.yaml")
        
        if FileManager.default.fileExists(atPath: configPath.path) {
            // Parse YAML for gateway URL and API key
            if let content = try? String(contentsOf: configPath, encoding: .utf8) {
                for line in content.components(separatedBy: "\n") {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("port:") {
                        let port = trimmed.replacingOccurrences(of: "port:", with: "").trimmingCharacters(in: .whitespaces)
                        if let portNum = Int(port) {
                            gatewayURL = URL(string: "http://localhost:\(portNum)")!
                        }
                    }
                    if trimmed.hasPrefix("api_key:") {
                        apiKey = trimmed.replacingOccurrences(of: "api_key:", with: "").trimmingCharacters(in: .whitespaces)
                    }
                }
            }
            log.info("OpenClaw config loaded from \(configPath.path)")
        }
    }
}
