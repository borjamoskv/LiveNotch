import Foundation
import Combine

// ═══════════════════════════════════════════════════
// MARK: - 📡 NotchRelay — Zero-Permission Cloud Bridge
// ═══════════════════════════════════════════════════
//
// Connects the Mac Notch to a Laravel backend.
// Uses SSE (Server-Sent Events) for real-time receive.
// Uses REST API for sending state back.
//
// Architecture:
//   iPhone → POST /api/notch/command → Laravel cache → SSE → Mac Notch
//   Laravel Faro → cache → SSE → Mac Notch (crypto, NFT, alerts)
//   Mac Notch → POST /api/notch/state → Laravel DB → iPhone polls
//
// NO WebSocket server needed. NO third-party services.
// Just standard PHP + nginx + this Swift client.
//
// Philosophy: "Zero permissions. Full power."

@MainActor
final class NotchRelay: ObservableObject {
    static let shared = NotchRelay()
    
    // ── Connection State ──
    enum ConnectionState: String {
        case disconnected = "Disconnected"
        case connecting   = "Connecting"
        case connected    = "Connected"
        case reconnecting = "Reconnecting"
    }
    
    @Published var state: ConnectionState = .disconnected
    @Published var isPhoneConnected: Bool = false
    @Published var lastCommand: RelayCommand? = nil
    @Published var latencyMs: Int = 0
    
    // ── Config ──
    var baseURL: String = "https://api.moskv.com" {
        didSet { NotchPersistence.shared.set(.relayBaseURL, value: baseURL) }
    }
    private var deviceToken: String = ""
    private var apiKey: String = ""
    
    // ── SSE ──
    private var sseTask: URLSessionDataTask?
    private var session: URLSession?
    private var reconnectTimer: Timer?
    private var stateUpdateTimer: Timer?
    private var reconnectAttempts: Int = 0
    private let maxReconnectAttempts: Int = 10
    
    private init() {
        loadCredentials()
    }
    
    deinit {
        sseTask?.cancel()
        session?.invalidateAndCancel()
        reconnectTimer?.invalidate()
        stateUpdateTimer?.invalidate()
    }
    
    // ════════════════════════════════════════
    // MARK: - Connection Lifecycle
    // ════════════════════════════════════════
    
    /// Start SSE connection to receive commands from iPhone/Faro
    func connect() {
        guard state != .connected, !deviceToken.isEmpty else { return }
        state = .connecting
        
        let url = URL(string: "\(baseURL)/api/notch/stream/\(deviceToken)")!
        var request = URLRequest(url: url)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = TimeInterval(Int.max) // Keep alive
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300 // 5 min timeout
        config.timeoutIntervalForResource = 3600 // 1 hour max
        
        let delegate = SSEDelegate { [weak self] data in
            Task { @MainActor in
                self?.handleSSEData(data)
            }
        } onError: { [weak self] in
            Task { @MainActor in
                self?.scheduleReconnect()
            }
        }
        
        session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        sseTask = session?.dataTask(with: request)
        sseTask?.resume()
        
        // Mark connected after brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            if self?.state == .connecting {
                self?.state = .connected
                self?.reconnectAttempts = 0
                NSLog("📡 NotchRelay: SSE connected ✓")
            }
        }
        
        // Start periodic state updates to backend
        startStateUpdates()
        
        NSLog("📡 NotchRelay: Connecting SSE to \(baseURL)")
    }
    
    /// Disconnect
    func disconnect() {
        sseTask?.cancel()
        sseTask = nil
        session?.invalidateAndCancel()
        session = nil
        reconnectTimer?.invalidate()
        stateUpdateTimer?.invalidate()
        state = .disconnected
        isPhoneConnected = false
        NSLog("📡 NotchRelay: Disconnected")
    }
    
    /// Auto-reconnect with exponential backoff
    private func scheduleReconnect() {
        guard reconnectAttempts < maxReconnectAttempts else {
            state = .disconnected
            NSLog("📡 NotchRelay: Max reconnect attempts reached")
            return
        }
        
        state = .reconnecting
        reconnectAttempts += 1
        let delay = min(Double(reconnectAttempts) * 2.0, 30.0)
        
        NSLog("📡 NotchRelay: Reconnecting in \(delay)s (attempt \(reconnectAttempts))")
        
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.disconnect()
                self?.connect()
            }
        }
    }
    
    // ════════════════════════════════════════
    // MARK: - SSE Data Handling
    // ════════════════════════════════════════
    
    private func handleSSEData(_ text: String) {
        // SSE format: "data: {json}\n\n"
        let lines = text.components(separatedBy: "\n")
        for line in lines {
            guard line.hasPrefix("data: ") else { continue }
            let jsonStr = String(line.dropFirst(6))
            handleJSON(jsonStr)
        }
    }
    
    private func handleJSON(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return
        }
        
        switch type {
        // ── Heartbeat ──
        case "heartbeat":
            break // Keep-alive, ignore
            
        // ── Phone connected/disconnected ──
        case "phone.connected":
            isPhoneConnected = true
            HapticManager.shared.play(.toggle)
            NSLog("📡 NotchRelay: iPhone connected 📱")
            
        case "phone.disconnected":
            isPhoneConnected = false
            NSLog("📡 NotchRelay: iPhone disconnected")
            
        // ── Mode changes ──
        case "mode.change":
            if let modeData = json["data"] as? [String: Any],
               let modeName = modeData["mode"] as? String,
               let mode = UserMode(rawValue: modeName) {
                UserModeManager.shared.activeMode = mode
                lastCommand = .modeChange(mode)
                NSLog("📡 NotchRelay: Mode → \(modeName)")
            }
            
        // ── Music controls ──
        case "music.toggle":
            lastCommand = .musicToggle
            NotificationCenter.default.post(name: .relayMusicToggle, object: nil)
            
        case "music.next":
            lastCommand = .musicNext
            NotificationCenter.default.post(name: .relayMusicNext, object: nil)
            
        case "music.previous":
            lastCommand = .musicPrevious
            NotificationCenter.default.post(name: .relayMusicPrevious, object: nil)
            
        case "music.volume":
            if let volumeData = json["data"] as? [String: Any],
               let volume = volumeData["value"] as? Float {
                lastCommand = .volumeChange(volume)
                NotificationCenter.default.post(name: .relayVolumeChange, object: volume)
            }
            
        // ── Faro Alert (Server Push) ──
        case "faro.alert":
            let color = json["color"] as? String ?? "#FFFFFF"
            let message = json["message"] as? String ?? ""
            let icon = json["icon"] as? String ?? "bell.fill"
            let duration = json["duration"] as? Int ?? 5
            let intensity = json["intensity"] as? String ?? "medium"
            
            lastCommand = .faroAlert(
                color: color,
                message: message,
                icon: icon,
                duration: duration,
                intensity: intensity
            )
            
            NotificationCenter.default.post(name: .relayFaroAlert, object: [
                "color": color,
                "message": message,
                "icon": icon,
                "duration": duration,
                "intensity": intensity,
            ] as [String: Any])
            
            NSLog("📡 Faro: \(message) → color: \(color)")
            
        default:
            NSLog("📡 NotchRelay: Unknown type: \(type)")
        }
    }
    
    // ════════════════════════════════════════
    // MARK: - Send State (Mac → Backend)
    // ════════════════════════════════════════
    
    /// Periodically push Mac state to backend for iPhone to poll
    private func startStateUpdates() {
        stateUpdateTimer?.invalidate()
        stateUpdateTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pushCurrentState()
            }
        }
    }
    
    private func pushCurrentState() {
        guard state == .connected else { return }
        
        _ = UserModeManager.shared
        
        // State is collected via the onStateRequest closure (set by NotchViewModel)
        guard let stateData = onCollectState?() else { return }
        
        var payload = stateData
        payload["device_token"] = deviceToken
        
        postJSON(to: "/api/notch/state", body: ["device_token": deviceToken, "state": payload]) { _ in }
    }
    
    /// Closure that NotchViewModel sets to provide current state data
    var onCollectState: (() -> [String: Any])?
    
    // ════════════════════════════════════════
    // MARK: - Pairing
    // ════════════════════════════════════════
    
    /// Request a 6-digit pairing code from the server
    func requestPairCode(completion: @escaping (String?) -> Void) {
        let body: [String: Any] = [
            "device_token": deviceToken,
            "device_name": Host.current().localizedName ?? "Mac",
        ]
        
        postJSON(to: "/api/notch/pair", body: body) { result in
            if let code = result?["code"] as? String {
                completion(code)
            } else {
                completion(nil)
            }
        }
    }
    
    // ════════════════════════════════════════
    // MARK: - HTTP Helpers
    // ════════════════════════════════════════
    
    private func postJSON(to path: String, body: [String: Any], completion: @escaping ([String: Any]?) -> Void) {
        guard let url = URL(string: "\(baseURL)\(path)"),
              let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion(nil)
                return
            }
            completion(json)
        }.resume()
    }
    
    // ════════════════════════════════════════
    // MARK: - Credentials
    // ════════════════════════════════════════
    
    private func loadCredentials() {
        let stored = NotchPersistence.shared.string(.relayBaseURL)
        if !stored.isEmpty {
            baseURL = stored
        }
        
        let existingToken = NotchPersistence.shared.string(.relayDeviceToken)
        if !existingToken.isEmpty {
            deviceToken = existingToken
        } else {
            deviceToken = UUID().uuidString
            NotchPersistence.shared.set(.relayDeviceToken, value: deviceToken)
        }
        
        let storedKey = NotchPersistence.shared.string(.relayApiKey)
        if !storedKey.isEmpty {
            apiKey = storedKey
        }
    }
    
    func savePairing(apiKey: String) {
        self.apiKey = apiKey
        NotchPersistence.shared.set(.relayApiKey, value: apiKey)
    }
}

// ═══════════════════════════════════════════════════
// MARK: - SSE Delegate (URLSession streaming)
// ═══════════════════════════════════════════════════

/// Handles chunked SSE responses from Laravel
private class SSEDelegate: NSObject, URLSessionDataDelegate {
    let onData: (String) -> Void
    let onError: () -> Void
    
    init(onData: @escaping (String) -> Void, onError: @escaping () -> Void) {
        self.onData = onData
        self.onError = onError
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if let text = String(data: data, encoding: .utf8) {
            onData(text)
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if error != nil {
            onError()
        }
    }
}

// ═══════════════════════════════════════════════════
// MARK: - Relay Data Models
// ═══════════════════════════════════════════════════

/// Commands received from phone or Faro
enum RelayCommand {
    case modeChange(UserMode)
    case musicToggle
    case musicNext
    case musicPrevious
    case volumeChange(Float)
    case exclusiveAudio(Bool)
    case faroAlert(color: String, message: String, icon: String, duration: Int, intensity: String)
    case custom(String)
}

// ═══════════════════════════════════════════════════
// MARK: - Notification Names
// ═══════════════════════════════════════════════════

extension Notification.Name {
    static let relayMusicToggle = Notification.Name("notch.relay.music.toggle")
    static let relayMusicNext = Notification.Name("notch.relay.music.next")
    static let relayMusicPrevious = Notification.Name("notch.relay.music.previous")
    static let relayVolumeChange = Notification.Name("notch.relay.volume.change")
    static let relayExclusiveAudio = Notification.Name("notch.relay.audio.exclusive")
    static let relayFaroAlert = Notification.Name("notch.relay.faro.alert")
}
