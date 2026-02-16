import SwiftUI
import AppKit

// ═══════════════════════════════════════════════════
// MARK: - 🧠 Menu Bar Intelligence
// ═══════════════════════════════════════════════════
// Context-aware menu bar management:
// - DAW active → music controls priority
// - Video call → AirLock hint
// - Auto-collapse when notch-aware layout needed
// - Detect frontmost app category for smart behavior

@MainActor
final class MenuBarIntelligence: ObservableObject {
    static let shared = MenuBarIntelligence()
    
    enum AppContext {
        case daw        // Logic, Ableton, FL Studio, Reaper
        case creative   // Figma, Sketch, Photoshop, Blender
        case browser    // Safari, Chrome, Firefox, Arc
        case videoCall  // Zoom, Teams, FaceTime, Discord
        case coding     // Xcode, VS Code, Terminal
        case general    // Everything else
    }
    
    @Published var currentContext: AppContext = .general
    @Published var frontmostApp: String = ""
    @Published var shouldSuggestAirLock: Bool = false
    
    private var pollTimer: Timer?
    
    // App bundle IDs mapped to contexts
    private let contextMap: [String: AppContext] = [
        // DAW
        "com.apple.logic10": .daw,
        "com.ableton.live": .daw,
        "com.image-line.flstudio": .daw,
        "com.cockos.reaper": .daw,
        "com.native-instruments.Maschine2": .daw,
        "com.bitwig.studio": .daw,
        // Creative
        "com.figma.Desktop": .creative,
        "com.bohemiancoding.sketch3": .creative,
        "com.adobe.Photoshop": .creative,
        "org.blenderfoundation.blender": .creative,
        "com.adobe.illustrator": .creative,
        // Browser
        "com.apple.Safari": .browser,
        "com.google.Chrome": .browser,
        "org.mozilla.firefox": .browser,
        "company.thebrowser.Browser": .browser, // Arc
        // Video Call
        "us.zoom.xos": .videoCall,
        "com.microsoft.teams2": .videoCall,
        "com.apple.FaceTime": .videoCall,
        "com.hnc.Discord": .videoCall,
        // Coding
        "com.apple.dt.Xcode": .coding,
        "com.microsoft.VSCode": .coding,
        "com.googlecode.iterm2": .coding,
        "com.apple.Terminal": .coding,
    ]
    
    private init() { startMonitoring() }
    
    deinit {
        pollTimer?.invalidate()
    }
    
    func startMonitoring() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateContext() }
        }
    }
    
    private func updateContext() {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        let bundleID = app.bundleIdentifier ?? ""
        frontmostApp = app.localizedName ?? "Unknown"
        
        let newContext = contextMap[bundleID] ?? .general
        if newContext != currentContext {
            currentContext = newContext
            shouldSuggestAirLock = (newContext == .videoCall)
        }
    }
    
    /// Suggested notch priority panel based on context
    var suggestedPanel: String {
        switch currentContext {
        case .daw: return "music"
        case .creative: return "tools"
        case .browser: return "media"
        case .videoCall: return "privacy"
        case .coding: return "terminal"
        case .general: return "default"
        }
    }
    
    func stopMonitoring() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
}
