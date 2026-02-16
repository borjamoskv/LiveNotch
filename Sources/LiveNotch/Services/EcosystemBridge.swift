import SwiftUI
import Combine
import Foundation
import IOKit.ps

// ═══════════════════════════════════════════════════════════
// MARK: - ⌚ EcosystemBridge — Unified Apple Accessory Hub
// ═══════════════════════════════════════════════════════════
// Monitors AirPods, Apple Watch, iPhone battery & connection
// state. Provides audio routing, smart handoff, and unified
// battery prediction. Data from IOKit + IOBluetooth runtime.
//
// Architecture: Bridge pattern — ready for real Bluetooth
// data OR simulated state for development/testing.

@MainActor
final class EcosystemBridge: ObservableObject {
    static let shared = EcosystemBridge()
    private let log = NotchLog.make("EcosystemBridge")
    
    // ─── Accessory State ───
    @Published var accessories: [AccessoryState] = []
    @Published var activeAudioDevice: AudioDevice = .mac
    @Published var airpodsANC: ANCMode = .off
    @Published var unifiedBatteryEstimate: String = "—"
    
    // ─── Biometric State (Watch) ───
    @Published var heartRate: Int = 0               // bpm
    @Published var heartRateZone: HeartRateZone = .rest
    @Published var steps: Int = 0
    @Published var distanceKm: Double = 0.0
    @Published var bloodOxygen: Int = 0             // SpO2 %
    @Published var sleepHours: Double = 0.0
    @Published var stressLevel: Double = 0.0        // 0..1
    
    // ─── Context ───
    @Published var detectedActivity: ActivityContext = .idle
    @Published var automationSuggestion: String? = nil
    
    private var pollTimer: AnyCancellable?
    
    // ═══════════════════════════════════════════════════
    // MARK: - Types
    // ═══════════════════════════════════════════════════
    
    struct AccessoryState: Identifiable, Equatable {
        let id: String
        let name: String
        let type: AccessoryType
        var batteryLeft: Int          // 0..100, -1 = unknown
        var batteryRight: Int         // AirPods only
        var batteryCase: Int          // AirPods only
        var isConnected: Bool
        var isActive: Bool            // Currently routing audio
        var signalStrength: Int       // 0..5
        
        var batteryDisplay: String {
            switch type {
            case .airpods:
                return "L:\(batteryLeft)% R:\(batteryRight)%"
            case .watch:
                return "⌚\(batteryLeft)%"
            case .iphone:
                return "📱\(batteryLeft)%"
            case .mac:
                let level = Self.readMacBattery()
                return "💻\(level)%"
            }
        }
        
        var statusIcon: String {
            if isActive { return "●" }
            if isConnected { return "○" }
            return "—"
        }
        
        var batteryColor: String {
            let level = batteryLeft
            if level < 20 { return "red" }
            if level < 50 { return "yellow" }
            return "green"
        }
        
        static func readMacBattery() -> Int {
            guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
                  let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [Any],
                  let first = sources.first,
                  let desc = IOPSGetPowerSourceDescription(snapshot, first as CFTypeRef)?.takeUnretainedValue() as? [String: Any],
                  let capacity = desc[kIOPSCurrentCapacityKey as String] as? Int else {
                return 100
            }
            return capacity
        }
    }
    
    enum AccessoryType: String, CaseIterable {
        case airpods, watch, iphone, mac
    }
    
    enum AudioDevice: String, CaseIterable {
        case mac = "Mac"
        case watch = "Watch"
        case iphone = "iPhone"
        case airpods = "AirPods"
        case none = "None"
    }
    
    enum ANCMode: String, CaseIterable {
        case off = "Off"
        case noiseCancel = "ANC"
        case transparency = "Transparency"
        case adaptive = "Adaptive"
    }
    
    enum HeartRateZone: String {
        case rest = "Rest"          // < 60
        case light = "Light"        // 60-100
        case moderate = "Moderate"  // 100-140
        case vigorous = "Vigorous"  // 140-170
        case peak = "Peak"          // > 170
        
        var color: Color {
            switch self {
            case .rest: return .blue
            case .light: return .green
            case .moderate: return .yellow
            case .vigorous: return .orange
            case .peak: return .red
            }
        }
        
        var semaphore: String {
            switch self {
            case .rest: return "●○○○○"
            case .light: return "●●○○○"
            case .moderate: return "●●●○○"
            case .vigorous: return "●●●●○"
            case .peak: return "●●●●●"
            }
        }
        
        static func from(bpm: Int) -> HeartRateZone {
            switch bpm {
            case ..<60: return .rest
            case 60..<100: return .light
            case 100..<140: return .moderate
            case 140..<170: return .vigorous
            default: return .peak
            }
        }
    }
    
    enum ActivityContext: String {
        case idle = "Idle"
        case working = "Working"
        case meeting = "Meeting"
        case exercise = "Exercise"
        case commuting = "Commuting"
        case relaxing = "Relaxing"
    }
    
    // ═══════════════════════════════════════════════════
    // MARK: - Initialization
    // ═══════════════════════════════════════════════════
    
    init() {
        loadSimulatedState()
        startPolling()
        log.info("EcosystemBridge Online — \(accessories.count) accessories")
    }
    
    // ═══════════════════════════════════════════════════
    // MARK: - Audio Routing
    // ═══════════════════════════════════════════════════
    
    /// Switch audio to a different device with crossfade
    func switchAudio(to device: AudioDevice) {
        guard device != activeAudioDevice else { return }
        log.info("Audio switch: \(activeAudioDevice.rawValue) → \(device.rawValue)")
        
        // Mark old device inactive
        for i in accessories.indices {
            accessories[i].isActive = false
        }
        
        // Activate new device
        activeAudioDevice = device
        if let idx = accessories.firstIndex(where: {
            $0.type.rawValue == device.rawValue.lowercased()
        }) {
            accessories[idx].isActive = true
        }
    }
    
    /// Cycle to next connected device
    func cycleAudioDevice() {
        let connected = accessories.filter { $0.isConnected }
        guard let currentIdx = connected.firstIndex(where: { $0.isActive }) else { return }
        let nextIdx = (currentIdx + 1) % connected.count
        let nextType = connected[nextIdx].type
        switch nextType {
        case .mac: switchAudio(to: .mac)
        case .watch: switchAudio(to: .watch)
        case .iphone: switchAudio(to: .iphone)
        case .airpods: switchAudio(to: .mac) // AirPods route through active device
        }
    }
    
    /// Toggle ANC mode
    func toggleANC() {
        let modes = ANCMode.allCases
        guard let idx = modes.firstIndex(of: airpodsANC) else { return }
        airpodsANC = modes[(idx + 1) % modes.count]
        log.info("ANC → \(airpodsANC.rawValue)")
    }
    
    /// Set ANC to a specific mode
    func setANC(_ mode: ANCMode) {
        guard mode != airpodsANC else { return }
        airpodsANC = mode
        log.info("ANC set → \(mode.rawValue)")
    }
    
    // ═══════════════════════════════════════════════════
    // MARK: - Context Automation
    // ═══════════════════════════════════════════════════
    
    func detectContext() {
        let nervous = NervousSystem.shared
        let appName = nervous.activeAppName.lowercased()
        
        // Meeting detection
        if appName.contains("zoom") || appName.contains("teams") || appName.contains("meet") {
            detectedActivity = .meeting
            automationSuggestion = "🎙 ANC ON + Mac Priority?"
            return
        }
        
        // Exercise detection (Watch steps > threshold)
        if steps > 0 {
            let recentStepRate = Double(steps) / max(1, Date().timeIntervalSince(.distantPast) / 60)
            if recentStepRate > 100 {
                detectedActivity = .exercise
                automationSuggestion = "🏃 Switch to Watch + Sport EQ?"
                return
            }
        }
        
        // Work detection
        if appName.contains("xcode") || appName.contains("code") || appName.contains("terminal") {
            detectedActivity = .working
            automationSuggestion = nil
            return
        }
        
        detectedActivity = .idle
        automationSuggestion = nil
    }
    
    /// Apply automation suggestion
    func applyAutomation() {
        switch detectedActivity {
        case .meeting:
            switchAudio(to: .mac)
            airpodsANC = .noiseCancel
        case .exercise:
            switchAudio(to: .watch)
            airpodsANC = .transparency
        default:
            break
        }
        automationSuggestion = nil
    }
    
    // ═══════════════════════════════════════════════════
    // MARK: - Battery Prediction
    // ═══════════════════════════════════════════════════
    
    func updateBatteryPrediction() {
        let totalMinutes = accessories.reduce(0) { sum, acc in
            guard acc.isConnected else { return sum }
            // Rough estimate: 1% ≈ 3 minutes for AirPods, 6 min for Watch
            let rate: Double = acc.type == .airpods ? 3.0 : 6.0
            return sum + Int(Double(acc.batteryLeft) * rate)
        }
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        unifiedBatteryEstimate = "\(hours)h \(mins)m"
    }
    
    // ═══════════════════════════════════════════════════
    // MARK: - Simulated State (Development)
    // ═══════════════════════════════════════════════════
    
    private func loadSimulatedState() {
        accessories = [
            AccessoryState(
                id: "airpods-pro", name: "AirPods Pro",
                type: .airpods,
                batteryLeft: 87, batteryRight: 85, batteryCase: 92,
                isConnected: true, isActive: true, signalStrength: 5
            ),
            AccessoryState(
                id: "apple-watch", name: "Apple Watch",
                type: .watch,
                batteryLeft: 23, batteryRight: -1, batteryCase: -1,
                isConnected: true, isActive: false, signalStrength: 4
            ),
            AccessoryState(
                id: "iphone", name: "iPhone",
                type: .iphone,
                batteryLeft: 68, batteryRight: -1, batteryCase: -1,
                isConnected: true, isActive: false, signalStrength: 3
            ),
            AccessoryState(
                id: "mac", name: "MacBook Pro",
                type: .mac,
                batteryLeft: AccessoryState.readMacBattery(),
                batteryRight: -1, batteryCase: -1,
                isConnected: true, isActive: false, signalStrength: 5
            )
        ]
        
        // Simulated biometrics
        heartRate = 72
        heartRateZone = .light
        steps = 3247
        distanceKm = 2.8
        bloodOxygen = 98
        sleepHours = 6.7
        stressLevel = 0.3
    }
    
    private func startPolling() {
        pollTimer = Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.simulateBiometricDrift()
                self?.detectContext()
                self?.updateBatteryPrediction()
            }
    }
    
    /// Simulate realistic biometric drift for development
    private func simulateBiometricDrift() {
        heartRate += Int.random(in: -3...3)
        heartRate = max(55, min(180, heartRate))
        heartRateZone = HeartRateZone.from(bpm: heartRate)
        
        steps += Int.random(in: 0...15)
        distanceKm = Double(steps) / 1300.0
        
        bloodOxygen += Int.random(in: -1...1)
        bloodOxygen = max(92, min(100, bloodOxygen))
        
        stressLevel += Double.random(in: -0.05...0.05)
        stressLevel = max(0, min(1, stressLevel))
        
        // Drain batteries slowly
        for i in accessories.indices {
            if accessories[i].isActive && Bool.random() {
                accessories[i].batteryLeft = max(0, accessories[i].batteryLeft - 1)
            }
        }
    }
}
