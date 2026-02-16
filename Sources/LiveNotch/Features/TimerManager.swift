import SwiftUI
import UserNotifications

// ═══════════════════════════════════════════════════
// MARK: - ⏱️ Timer Manager (Pomodoro + Focus)
// ═══════════════════════════════════════════════════
// Extracted from NotchViewModel — owns timer state and pomodoro logic.
// Single Responsibility: Countdown timer, focus mode, notifications.

@MainActor
final class TimerManager: ObservableObject {
    
    @Published var timerSeconds: Int = 0
    @Published var timerActive = false
    @Published var pomodoroMinutes: Int = 25
    
    private var timer: Timer?
    
    /// Callback for status messages (connected by NotchViewModel)
    var onStatusMessage: ((String, String) -> Void)?
    
    init() {}
    
    deinit {
        timer?.invalidate()
    }
    
    // ════════════════════════════════════════
    // MARK: - Timer Control
    // ════════════════════════════════════════
    
    func start(minutes: Int? = nil) {
        if let m = minutes { pomodoroMinutes = m }
        
        timer?.invalidate()
        timerSeconds = pomodoroMinutes * 60
        timerActive = true
        
        // Focus Mode integration
        if pomodoroMinutes >= 10 {
            onStatusMessage?("Focus Mode: ON", "moon.stars.fill")
            runShortcut("Notch Focus On")
        } else {
            onStatusMessage?("Timer: \(pomodoroMinutes)m", "timer")
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if self.timerSeconds > 0 {
                    self.timerSeconds -= 1
                } else {
                    self.complete()
                }
            }
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
        timerActive = false
        timerSeconds = 0
        runShortcut("Notch Focus Off")
    }
    
    private func complete() {
        stop()
        HapticManager.shared.play(.success)
        
        // System notification
        let content = UNMutableNotificationContent()
        content.title = "⏰ Timer Complete!"
        content.subtitle = "Your \(pomodoroMinutes)-minute session is done."
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    // ════════════════════════════════════════
    // MARK: - Computed Properties
    // ════════════════════════════════════════
    
    var timerDisplay: String {
        String(format: "%02d:%02d", timerSeconds / 60, timerSeconds % 60)
    }
    
    var timerProgress: Double {
        guard pomodoroMinutes > 0 else { return 0 }
        let total = Double(pomodoroMinutes * 60)
        return 1.0 - (Double(timerSeconds) / total)
    }
    
    // ════════════════════════════════════════
    // MARK: - Helpers
    // ════════════════════════════════════════
    
    private func runShortcut(_ name: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = ["run", name]
        try? process.run()
    }
}
