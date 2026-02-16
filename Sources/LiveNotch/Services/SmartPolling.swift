import AppKit
import Combine

// ═══════════════════════════════════════════════════
// MARK: - ⚡ Smart Polling Coordinator V2
// ═══════════════════════════════════════════════════
// Central timer coordinator that:
// 1. Replaces per-service Timer instances with a single dispatch source
// 2. Adapts polling rates based on user activity (active/idle/sleeping)
// 3. Reduces CPU/battery drain when the system is idle

final class SmartPolling {
    static let shared = SmartPolling()
    
    // ── Activity Levels ──
    enum ActivityLevel: String {
        case active      // User interacting — full polling rates
        case idle        // No interaction 5+ min — reduced rates
        case sleeping    // Screen locked — near-pause
    }
    
    // ── Poll Interval Modes ──
    enum PollInterval {
        case fixed(TimeInterval)                          // Same rate always
        case adaptive(active: TimeInterval, idle: TimeInterval) // Adjusts with activity
    }
    
    // ── Internal Registration ──
    private struct Registration {
        let id: String
        let interval: PollInterval
        let action: () -> Void
        var lastFire: Date = .distantPast
    }
    
    // ── State ──
    @Published private(set) var level: ActivityLevel = .active
    private var registrations: [String: Registration] = [:]
    private var coordinatorTimer: Timer?
    private var lastEventTime = Date()
    private var cancellables = Set<AnyCancellable>()
    
    // ── Tick Rate ──
    // The coordinator ticks at the GCD of all registered intervals.
    // For simplicity, tick every 0.5s and dispatch eligible polls.
    private let tickInterval: TimeInterval = 0.5
    
    private init() {
        setupActivityDetection()
        startCoordinator()
    }
    
    deinit {
        coordinatorTimer?.invalidate()
        cancellables.removeAll()
    }
    
    // ═══════════════════════════════════════════════
    // MARK: - Public API
    // ═══════════════════════════════════════════════
    
    /// Register a poll with the coordinator
    func register(_ id: String, interval: PollInterval, action: @escaping () -> Void) {
        registrations[id] = Registration(id: id, interval: interval, action: action)
    }
    
    /// Unregister a poll
    func unregister(_ id: String) {
        registrations.removeValue(forKey: id)
    }
    
    /// Force an immediate poll for a specific registration
    func fireNow(_ id: String) {
        guard var reg = registrations[id] else { return }
        reg.action()
        reg.lastFire = Date()
        registrations[id] = reg
    }
    
    /// Returns the effective interval for a poll given current activity
    func effectiveInterval(for interval: PollInterval) -> TimeInterval {
        switch interval {
        case .fixed(let t):
            return level == .sleeping ? t * 5 : t
        case .adaptive(let active, let idle):
            switch level {
            case .active:   return active
            case .idle:     return idle
            case .sleeping: return idle * 3
            }
        }
    }
    
    /// Convenience: returns optimal interval for a base rate
    func interval(base: TimeInterval) -> TimeInterval {
        switch level {
        case .active: return base
        case .idle: return base * 3
        case .sleeping: return base * 10
        }
    }
    
    // ═══════════════════════════════════════════════
    // MARK: - Coordinator Engine
    // ═══════════════════════════════════════════════
    
    private func startCoordinator() {
        coordinatorTimer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }
    
    private func tick() {
        let now = Date()
        
        for (id, var reg) in registrations {
            let effective = effectiveInterval(for: reg.interval)
            let elapsed = now.timeIntervalSince(reg.lastFire)
            
            if elapsed >= effective {
                reg.action()
                reg.lastFire = now
                registrations[id] = reg
            }
        }
    }
    
    // ═══════════════════════════════════════════════
    // MARK: - Activity Detection
    // ═══════════════════════════════════════════════
    
    private func setupActivityDetection() {
        // Global mouse/keyboard events → mark active
        NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .keyDown]) { [weak self] _ in
            self?.lastEventTime = Date()
            if self?.level != .active {
                self?.level = .active
            }
        }
        
        // Periodic idle check (every 30s)
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let idleSeconds = Date().timeIntervalSince(self.lastEventTime)
            if idleSeconds > 300 { // 5 minutes
                if self.level != .idle {
                    self.level = .idle
                }
            }
        }
        
        // Screen sleep/wake
        let ws = NSWorkspace.shared.notificationCenter
        ws.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
            self?.level = .sleeping
        }
        ws.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.level = .active
            self?.lastEventTime = Date()
        }
    }
}
