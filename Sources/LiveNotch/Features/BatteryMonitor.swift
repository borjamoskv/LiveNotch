import SwiftUI
import IOKit
import IOKit.ps

// ═══════════════════════════════════════════════════
// MARK: - 🔋 Battery Monitor
// ═══════════════════════════════════════════════════
// Extracted from NotchViewModel — owns battery state and monitoring.
// Single Responsibility: Battery level, charging status, icon.

@MainActor
final class BatteryMonitor: ObservableObject {
    
    @Published var batteryLevel: Int = 100
    @Published var isCharging = false
    
    private var timer: Timer?
    
    init() {
        update()
        startMonitor()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    // ════════════════════════════════════════
    // MARK: - Monitoring
    // ════════════════════════════════════════
    
    func update() {
        let s = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(s).takeRetainedValue() as [CFTypeRef]
        
        for source in sources {
            if let description = IOPSGetPowerSourceDescription(s, source).takeUnretainedValue() as? [String: Any] {
                let current = description[kIOPSCurrentCapacityKey] as? Int ?? 0
                let maxCapacity = description[kIOPSMaxCapacityKey] as? Int ?? 100
                
                if maxCapacity > 0 {
                    // Calculate percentage if the system returns raw mAh values
                    let calculated = (current * 100) / maxCapacity
                    // Clamp to 0-100 just in case
                    batteryLevel = min(100, max(0, calculated))
                }
                
                if let charging = description[kIOPSIsChargingKey] as? Bool {
                    isCharging = charging
                }
            }
        }
    }
    
    private func startMonitor() {
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.update() }
        }
    }
    
    // ════════════════════════════════════════
    // MARK: - Computed Properties
    // ════════════════════════════════════════
    
    var batteryIcon: String {
        if isCharging { return "battery.100.bolt" }
        switch batteryLevel {
        case 0..<10: return "battery.0"
        case 10..<25: return "battery.25"
        case 25..<50: return "battery.50"
        case 50..<75: return "battery.75"
        default: return "battery.100"
        }
    }
    
    var batteryColor: Color {
        if isCharging { return .green }
        switch batteryLevel {
        case 0..<15: return .red
        case 15..<30: return .orange
        default: return .green
        }
    }
    
    var isLow: Bool { batteryLevel < 20 && !isCharging }
}
