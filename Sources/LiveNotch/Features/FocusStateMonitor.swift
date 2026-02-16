import SwiftUI
import AppKit

// ═══════════════════════════════════════════════════
// MARK: - 🧘 Focus State Monitor
// ═══════════════════════════════════════════════════
// Extracted from NotchViewModel — tracks app switching and focus score.
// Single Responsibility: Measure how focused the user is.

@MainActor
final class FocusStateMonitor: ObservableObject {
    
    @Published var focusScore: Double = 1.0
    @Published var currentApp: String = ""
    
    private var timer: Timer?
    private var appSwitchCount: Int = 0
    private var focusWindowStart = Date()
    private var lastApp: String = ""
    
    // ── Context-Aware Mode ──
    @Published var isMinimalMode = false
    @Published var activeContextApp: String? = nil
    
    private let creativeApps = [
        "Photoshop", "Illustrator", "Final Cut Pro",
        "Premiere Pro", "DaVinci Resolve", "Logic Pro", "Ableton Live"
    ]
    
    /// Callback for status messages
    var onStatusMessage: ((String, String) -> Void)?
    
    init() {
        startMonitor()
        startContextMonitor()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    // ════════════════════════════════════════
    // MARK: - Flow State Tracking
    // ════════════════════════════════════════
    
    private func startMonitor() {
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                
                if let app = NSWorkspace.shared.frontmostApplication?.localizedName {
                    if app != self.lastApp {
                        self.appSwitchCount += 1
                        self.lastApp = app
                        self.currentApp = app
                    }
                }
                
                let elapsed = Date().timeIntervalSince(self.focusWindowStart)
                if elapsed > 300 { // 5 minute window
                    self.focusWindowStart = Date()
                    self.appSwitchCount = 0
                }
                
                let score = max(0, min(1.0, 1.0 - Double(self.appSwitchCount) * 0.08))
                withAnimation(.easeInOut(duration: 1.0)) {
                    self.focusScore = score
                }
            }
        }
    }
    
    // ════════════════════════════════════════
    // MARK: - Context Monitor
    // ════════════════════════════════════════
    
    private func startContextMonitor() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let name = app.localizedName else { return }
            
            Task { @MainActor in
                self.checkContext(for: name)
            }
        }
    }
    
    private func checkContext(for appName: String) {
        if creativeApps.contains(where: { appName.contains($0) }) {
            withAnimation {
                isMinimalMode = true
                activeContextApp = appName
                onStatusMessage?("Pro Mode", "pencil.and.outline")
            }
        } else {
            withAnimation {
                isMinimalMode = false
                activeContextApp = nil
            }
        }
    }
    
    // ════════════════════════════════════════
    // MARK: - Computed Properties
    // ════════════════════════════════════════
    
    var focusColor: Color {
        if focusScore > 0.7 { return .green }
        if focusScore > 0.4 { return .yellow }
        return .red
    }
    
    var focusLabel: String {
        if focusScore > 0.8 { return "Deep Focus" }
        if focusScore > 0.5 { return "Focused" }
        if focusScore > 0.3 { return "Distracted" }
        return "Scattered"
    }
}
