import Foundation
import Combine
import IOBluetooth

// ═══════════════════════════════════════════════════════════
// MARK: - 🎧 AirPodsBluetoothService — Real BT Detection
// ═══════════════════════════════════════════════════════════
// Detects connected AirPods via IOBluetooth, reads battery
// level, and publishes state changes. Falls back to simulated
// data when no real devices are found.
//
// NOTE: Apple does not expose public APIs to control ANC,
// Spatial Audio, or Adaptive EQ directly. Those toggles
// work as optimistic UI — the user controls them via the
// AirPods themselves or Control Center.

@MainActor
final class AirPodsBluetoothService: ObservableObject {
    static let shared = AirPodsBluetoothService()
    private let log = NotchLog.make("AirPodsBT")
    
    // ─── Published State ───
    @Published var isAirPodsConnected: Bool = false
    @Published var airPodsName: String = "AirPods Pro"
    @Published var batteryLeft: Int = -1        // 0..100, -1 = unknown
    @Published var batteryRight: Int = -1
    @Published var batteryCase: Int = -1
    @Published var isInEar: Bool = false
    @Published var firmwareVersion: String = "—"
    
    // ─── Internal ───
    private var pollTimer: AnyCancellable?
    private var discoveredDevice: IOBluetoothDevice?
    
    // Known AirPods product name prefixes
    private let airPodsIdentifiers = [
        "AirPods", "AirPods Pro", "AirPods Max",
        "Beats Fit Pro", "Beats Studio Buds"
    ]
    
    // ═══════════════════════════════════════════════════
    // MARK: - Initialization
    // ═══════════════════════════════════════════════════
    
    init() {
        scanForAirPods()
        startPolling()
        log.info("AirPodsBluetoothService initialized")
    }
    
    // ═══════════════════════════════════════════════════
    // MARK: - Device Discovery
    // ═══════════════════════════════════════════════════
    
    /// Scan paired Bluetooth devices for AirPods
    func scanForAirPods() {
        guard let pairedDevices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
            log.info("No paired Bluetooth devices found")
            loadFallbackState()
            return
        }
        
        for device in pairedDevices {
            let name = device.name ?? ""
            let isAirPods = airPodsIdentifiers.contains(where: { name.contains($0) })
            
            if isAirPods && device.isConnected() {
                discoveredDevice = device
                isAirPodsConnected = true
                airPodsName = name
                log.info("🎧 AirPods found: \(name) [Connected]")
                readBatteryFromDevice(device)
                return
            }
        }
        
        // No connected AirPods found — check for paired but disconnected
        for device in pairedDevices {
            let name = device.name ?? ""
            let isAirPods = airPodsIdentifiers.contains(where: { name.contains($0) })
            
            if isAirPods {
                airPodsName = name
                isAirPodsConnected = false
                log.info("🎧 AirPods paired but not connected: \(name)")
                loadFallbackState()
                return
            }
        }
        
        log.info("No AirPods found among \(pairedDevices.count) paired devices")
        loadFallbackState()
    }
    
    // ═══════════════════════════════════════════════════
    // MARK: - Battery Reading
    // ═══════════════════════════════════════════════════
    
    /// Attempt to read battery via IOBluetooth device properties
    private func readBatteryFromDevice(_ device: IOBluetoothDevice) {
        // IOBluetooth doesn't directly expose AirPods battery —
        // we use IORegistry to find the battery data published
        // by the Bluetooth daemon when AirPods are connected.
        readBatteryFromIORegistry()
    }
    
    /// Read AirPods battery from IORegistry (IOService matching)
    private func readBatteryFromIORegistry() {
        // The Bluetooth daemon publishes AirPods battery info
        // under IOService with class "AppleHSBluetoothDevice"
        // Keys: "BatteryPercentLeft", "BatteryPercentRight", "BatteryPercentCase"
        
        let matchingDict = IOServiceMatching("AppleHSBluetoothDevice") as NSDictionary as! [String: Any]
        var iterator: io_iterator_t = 0
        
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict as CFDictionary, &iterator)
        guard result == KERN_SUCCESS else {
            log.info("IORegistry: No AppleHSBluetoothDevice found (using simulated)")
            loadFallbackBattery()
            return
        }
        
        defer { IOObjectRelease(iterator) }
        
        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
            
            // Try to read battery properties
            var properties: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                  let dict = properties?.takeRetainedValue() as? [String: Any] else {
                continue
            }
            
            if let left = dict["BatteryPercentLeft"] as? Int {
                batteryLeft = left
            }
            if let right = dict["BatteryPercentRight"] as? Int {
                batteryRight = right
            }
            if let caseBat = dict["BatteryPercentCase"] as? Int {
                batteryCase = caseBat
            }
            if let inEar = dict["InEar"] as? Bool {
                isInEar = inEar
            }
            
            if batteryLeft >= 0 || batteryRight >= 0 {
                log.info("🔋 AirPods Battery — L:\(batteryLeft)% R:\(batteryRight)% Case:\(batteryCase)%")
                return
            }
        }
        
        // Fallback if IORegistry didn't have battery data
        loadFallbackBattery()
    }
    
    // ═══════════════════════════════════════════════════
    // MARK: - Polling
    // ═══════════════════════════════════════════════════
    
    private func startPolling() {
        pollTimer = Timer.publish(every: 15, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshState()
            }
    }
    
    func refreshState() {
        // Re-scan to detect connect/disconnect events
        let wasConnected = isAirPodsConnected
        scanForAirPods()
        
        if wasConnected != isAirPodsConnected {
            log.info("AirPods connection changed: \(wasConnected) → \(isAirPodsConnected)")
        }
    }
    
    // ═══════════════════════════════════════════════════
    // MARK: - Fallback (Simulated Data)
    // ═══════════════════════════════════════════════════
    
    private func loadFallbackState() {
        loadFallbackBattery()
    }
    
    private func loadFallbackBattery() {
        // Use EcosystemBridge simulated data as fallback
        batteryLeft = 87
        batteryRight = 85
        batteryCase = 92
        isInEar = true
    }
    
    // ═══════════════════════════════════════════════════
    // MARK: - Public Info
    // ═══════════════════════════════════════════════════
    
    var batteryDisplay: String {
        if batteryLeft < 0 && batteryRight < 0 { return "—" }
        return "L:\(max(0, batteryLeft))% R:\(max(0, batteryRight))%"
    }
    
    var caseDisplay: String {
        if batteryCase < 0 { return "—" }
        return "Case: \(batteryCase)%"
    }
    
    var overallBattery: Double {
        let left = max(0, batteryLeft)
        let right = max(0, batteryRight)
        return Double(left + right) / 200.0
    }
}
