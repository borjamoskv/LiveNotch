import SwiftUI
import AppKit
import IOKit.ps

// ═══════════════════════════════════════════════════
// MARK: - Agent Protocol
// ═══════════════════════════════════════════════════

protocol NotchAgent {
    var name: String { get }
    var emoji: String { get }
    var domain: String { get }
    
    /// How confident this agent is that it can handle the query (0.0 - 1.0)
    func confidence(for query: String, context: SensorFusion) -> Double
    
    /// Generate a response
    func respond(to query: String, context: SensorFusion, memory: ConversationMemory) async -> AgentResponse
}

struct AgentResponse {
    let text: String
    let confidence: Double
    let agentName: String
    let suggestedAction: SuggestedAction?
    
    enum SuggestedAction {
        case copyToClipboard(String)
        case openApp(String)
        case startWorkflow(String)
        case showNotification(String)
    }
}

// ═══════════════════════════════════════════════════
// MARK: - Sensor Fusion (System Awareness)
// ═══════════════════════════════════════════════════

struct SensorFusion {
    let activeAppBundle: String
    let activeAppName: String
    let cpuUsage: Double
    let batteryLevel: Int
    let isCharging: Bool
    let isPlayingMusic: Bool
    let currentTrack: String
    let currentArtist: String
    let currentMood: String
    let systemPrompt: String // From NervousSystem.currentAIContext
    let timeOfDay: TimeOfDay
    let clipboardContent: String?
    let activeProject: String
    
    enum TimeOfDay: String {
        case morning = "☀️ Morning"
        case afternoon = "🌤 Afternoon"
        case evening = "🌅 Evening"
        case night = "🌙 Night"
        case lateNight = "🦉 Late Night"
    }
    
    static func capture() -> SensorFusion {
        let hour = Calendar.current.component(.hour, from: Date())
        let timeOfDay: TimeOfDay
        switch hour {
        case 6..<12: timeOfDay = .morning
        case 12..<17: timeOfDay = .afternoon
        case 17..<21: timeOfDay = .evening
        case 21..<24: timeOfDay = .night
        default: timeOfDay = .lateNight
        }
        
        let nervous = NervousSystem.shared
        let clipboard = NSPasteboard.general.string(forType: .string)
        
        // Project Context Heuristics
        var project = "Global Context"
        let app = nervous.activeAppName.lowercased()
        if app.contains("xcode") { project = "LiveNotch (Swift)" }
        else if app.contains("code") || app.contains("cursor") { project = "Web/JS/Python Project" }
        else if app.contains("terminal") || app.contains("iterm") { project = "Shell/System" }
        else if app.contains("figma") { project = "Design System" }
        else if app.contains("ableton") || app.contains("logic") { project = "Audio Production" }
        
        return SensorFusion(
            activeAppBundle: nervous.activeAppBundleID,
            activeAppName: nervous.activeAppName,
            cpuUsage: SystemMonitor.shared.cpuUsage,
            batteryLevel: SensorFusion.readBatteryLevel(),
            isCharging: false,
            isPlayingMusic: nervous.isPlayingMusic,
            currentTrack: "", // Track info lives in NotchViewModel
            currentArtist: "",
            currentMood: nervous.currentMood.rawValue,
            systemPrompt: nervous.currentAIContext,
            timeOfDay: timeOfDay,
            clipboardContent: clipboard,
            activeProject: project
        )
    }
    
    /// Read actual battery level from IOKit power sources
    static func readBatteryLevel() -> Int {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
              let capacity = desc[kIOPSCurrentCapacityKey as String] as? Int else {
            return 100 // Fallback for desktops without battery
        }
        return capacity
    }
}
