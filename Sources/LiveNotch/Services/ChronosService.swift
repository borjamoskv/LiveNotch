import Foundation
import Combine
import UserNotifications

// ═══════════════════════════════════════════════════
// MARK: - ⏳ CHRONOS SERVICE
// ═══════════════════════════════════════════════════

@MainActor
final class ChronosService: ObservableObject {
    static let shared = ChronosService()
    
    enum Mode: String {
        case focus = "Focus"
        case shortBreak = "Short Break"
        case longBreak = "Long Break"
        
        var defaultDuration: TimeInterval {
            switch self {
            case .focus: return 25 * 60
            case .shortBreak: return 5 * 60
            case .longBreak: return 15 * 60
            }
        }
        
        var color: String {
            switch self {
            case .focus: return "amber" // DS.Colors.amber
            case .shortBreak: return "cyan" // DS.Colors.cyan
            case .longBreak: return "signalGreen" // DS.Colors.signalGreen
            }
        }
    }
    
    @Published var mode: Mode = .focus
    @Published var timeRemaining: TimeInterval = 25 * 60
    @Published var isActive: Bool = false
    @Published var progress: Double = 1.0 // 1.0 -> 0.0
    @Published var completedSessions: Int = 0
    
    private var timer: Timer?
    private var endDate: Date?
    
    private init() {
        requestNotificationPermission()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    func start() {
        guard !isActive else { return }
        
        isActive = true
        endDate = Date().addingTimeInterval(timeRemaining)
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.tick()
            }
        }
    }
    
    func pause() {
        isActive = false
        timer?.invalidate()
        timer = nil
    }
    
    func reset() {
        pause()
        timeRemaining = mode.defaultDuration
        progress = 1.0
    }
    
    func setMode(_ newMode: Mode) {
        mode = newMode
        reset()
    }
    
    private func tick() {
        guard let endDate = endDate else { return }
        
        let now = Date()
        timeRemaining = max(0, endDate.timeIntervalSince(now))
        
        let total = mode.defaultDuration
        progress = timeRemaining / total
        
        if timeRemaining <= 0 {
            complete()
        }
    }
    
    private func complete() {
        pause()
        timeRemaining = 0
        progress = 0
        if mode == .focus {
            completedSessions += 1
        }
        sendNotification()
        HapticManager.shared.play(.success)
    }
    
    var sessionCountDisplay: String {
        completedSessions == 0 ? "" : "\(completedSessions) session\(completedSessions == 1 ? "" : "s")"
    }
    
    // MARK: - Notifications
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
    
    private func sendNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Chronos: \(mode.rawValue) Complete"
        content.body = mode == .focus ? "Time to take a break." : "Ready to focus again?"
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
