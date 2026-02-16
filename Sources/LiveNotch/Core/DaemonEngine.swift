import SwiftUI
import AppKit
import Combine

// ═══════════════════════════════════════════════════
// MARK: - 👻 DAEMON ENGINE (The Shadow Self)
// ═══════════════════════════════════════════════════
// "Tu Sombra Digital". A background intelligence that
// judges your productivity.
//
// States:
// - Sleeping: You are focused (or idle).
// - Awake: You are transitioning or neutral.
// - Watching: You are potentially distracted.
// - Hunting: You are definitely distracted.
// ═══════════════════════════════════════════════════

enum DaemonState: String {
    case sleeping   // 💤 Eyes closed, invisible or dim
    case awake      // 👀 Eyes open, looking around
    case watching   // 👁️ Eyes fixed on cursor, suspicious
    case hunting    // 🔥 Eyes burning, entity descending
    case feasting   // 🩸 Entity obscures the distraction
}

@MainActor
final class DaemonEngine: ObservableObject {
    static let shared = DaemonEngine()
    
    // ── Published State ──
    @Published var state: DaemonState = .sleeping
    @Published var annoyanceLevel: Double = 0.0 // 0.0 to 1.0
    @Published var lastActiveApp: String = ""
    @Published var timeTodoDoom: TimeInterval = 0 // Seconds until attack
    
    // ── Configuration ──
    private let distractionApps = ["Safari", "Google Chrome", "Arc", "Twitter", "X", "Discord", "Slack", "Messages", "YouTube"]
    private let focusApps = ["Xcode", "Code", "Terminal", "iTerm2", "Figma", "Obsidian", "Final Cut Pro", "Logic Pro"]
    
    // ── Internals ──
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var isMonitoring = false
    
    private init() {
        // Start monitoring when created? Or wait for mode activation?
        // For now, responsive to UserModeManager
        UserModeManager.shared.$activeMode
            .sink { [weak self] mode in
                if mode == .daemon {
                    self?.startPossession()
                } else {
                    self?.exorcise()
                }
            }
            .store(in: &cancellables)
    }
    
    deinit {
        timer?.invalidate()
        cancellables.removeAll()
    }
    
    // ── Life Cycle ──
    
    func startPossession() {
        guard !isMonitoring else { return }
        isMonitoring = true
        annoyanceLevel = 0.0
        state = .awake
        
        // Check every 2 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.judgeCurrentActivity()
            }
        }
        
        NSLog("👻 Daemon invoked. Watching...")
    }
    
    func exorcise() {
        isMonitoring = false
        timer?.invalidate()
        timer = nil
        state = .sleeping
        annoyanceLevel = 0.0
        timeTodoDoom = 0
        NSLog("👻 Daemon banished.")
    }
    
    // ── Judgment Logic ──
    
    private func judgeCurrentActivity() {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        let appName = app.localizedName ?? "Unknown"
        lastActiveApp = appName
        
        let isDistracting = distractionApps.contains { appName.contains($0) }
        let isFocus = focusApps.contains { appName.contains($0) }
        
        if isDistracting {
            // INCREASE DOOM
            annoyanceLevel = min(1.0, annoyanceLevel + 0.05)
            timeTodoDoom += 2
            
            if annoyanceLevel > 0.8 {
                state = .feasting
            } else if annoyanceLevel > 0.4 {
                state = .hunting
            } else {
                state = .watching
            }
            
            // Haptic warning if transitioning to hunting
            if state == .hunting && annoyanceLevel < 0.45 {
                HapticManager.shared.play(.warning)
            }
            
        } else if isFocus {
            // REDUCE DOOM (Heal)
            annoyanceLevel = max(0.0, annoyanceLevel - 0.1)
            timeTodoDoom = max(0, timeTodoDoom - 5)
            
            if annoyanceLevel < 0.1 {
                state = .sleeping
            } else {
                state = .awake
            }
            
        } else {
            // NEUTRAL (Decay slowly)
            annoyanceLevel = max(0.0, annoyanceLevel - 0.02)
            if annoyanceLevel < 0.2 {
                state = .awake
            }
        }
    }
    
    // ── Interaction ──
    
    /// Called when the user clicks the Daemon (feeds it attention/pets it)
    func petTheDaemon() {
        annoyanceLevel = max(0.0, annoyanceLevel - 0.3)
        HapticManager.shared.play(.soft)
        state = .sleeping
    }
}
